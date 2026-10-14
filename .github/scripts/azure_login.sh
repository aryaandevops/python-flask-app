#!/usr/bin/env bash
# fix_azure_login.sh
# Create an Azure service principal, set AZURE_CREDENTIALS GitHub secret,
# update workflow to use creds, and open a PR.
#
# Usage:
#   ./fix_azure_login.sh \
#     --subscription-id YOUR_SUBSCRIPTION_ID \
#     --repo devopsbyraham/python-flask-app \
#     --workflow-path .github/workflows/main_rahamapp.yml
#
# If you run it inside a local clone of the repo it will create a branch,
# update the workflow file, commit, push and open a PR.

set -euo pipefail

# Defaults
REPO="devopsbyraham/python-flask-app"
WORKFLOW_PATH=".github/workflows/main_rahamapp.yml"
BRANCH_PREFIX="fix/azure-login-creds"
PR_TITLE="chore: use AZURE_CREDENTIALS for azure/login (fix workflow login error)"
PR_BODY="Use the AZURE_CREDENTIALS secret (SDK auth JSON) for azure/login@v2 to ensure all required values (clientId, tenantId, clientSecret, subscriptionId) are present. This fixes CI login failures."

# Helper: usage
usage() {
  cat <<EOF
Usage: $0 --subscription-id SUBSCRIPTION_ID [--repo owner/repo] [--workflow-path PATH] [--branch BRANCH_NAME] [--no-pr]
Examples:
  $0 --subscription-id 00000000-0000-0000-0000-000000000000
EOF
  exit 1
}

# Parse args
SUBSCRIPTION_ID=""
BRANCH_NAME=""
CREATE_PR=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription-id) SUBSCRIPTION_ID="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --workflow-path) WORKFLOW_PATH="$2"; shift 2;;
    --branch) BRANCH_NAME="$2"; shift 2;;
    --no-pr) CREATE_PR=false; shift;;
    --help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Error: --subscription-id is required"
  usage
fi

if [[ -z "$BRANCH_NAME" ]]; then
  BRANCH_NAME="${BRANCH_PREFIX}-$(date +%Y%m%d%H%M%S)"
fi

# Pre-checks
command -v az >/dev/null 2>&1 || { echo "az CLI required. Install from https://aka.ms/azcli"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "gh CLI required. Install from https://cli.github.com/"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required. Install it."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git required."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required."; exit 1; }

echo "Using repo: $REPO"
echo "Workflow path: $WORKFLOW_PATH"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo

# 1) Create service principal with SDK auth JSON
SP_NAME="github-actions-sp-$(date +%s)"
echo "Creating service principal $SP_NAME scoped to subscription $SUBSCRIPTION_ID..."
SP_JSON=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
  --sdk-auth 2>/dev/null) || {
    echo "Failed to create service principal. Ensure 'az login' is done and you have privileges to create SPs."; exit 1;
}

echo "Service principal created. (You can revoke it later with az ad sp delete --id <appId>)"
# Show a brief non-secret preview
echo "Preview (non-secret fields):"
echo "$SP_JSON" | jq '{clientId, subscriptionId, tenantId}' -c

# 2) Store as AZURE_CREDENTIALS secret in the repo
echo "Setting AZURE_CREDENTIALS secret in repo $REPO..."
# gh secret set reads stdin, but may require repository scope
echo "$SP_JSON" | gh secret set AZURE_CREDENTIALS --repo "$REPO" --body - >/dev/null
echo "AZURE_CREDENTIALS set."

# 3) Update workflow file to use creds instead of client-id/tenant-id/subscription-id
# This part edits the local file; it expects to be run inside a clone of the repo that contains the workflow path.
# Find local repo root that contains the workflow file.
WORKFLOW_ABS=""
CURRENT_DIR=$(pwd)
if [[ -f "$WORKFLOW_PATH" ]]; then
  WORKFLOW_ABS="$WORKFLOW_PATH"
else
  # try to find file under current repo
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    ROOT=$(git rev-parse --show-toplevel)
    if [[ -f "$ROOT/$WORKFLOW_PATH" ]]; then
      WORKFLOW_ABS="$ROOT/$WORKFLOW_PATH"
      cd "$ROOT" || exit 1
    fi
  fi
fi

if [[ -z "$WORKFLOW_ABS" ]]; then
  echo "Cannot find workflow file $WORKFLOW_PATH in current directory or parent git repo."
  echo "The script already set AZURE_CREDENTIALS secret; you must update the workflow manually to use it."
  echo "Recommended replacement in the azure/login step:"
  echo ""
  echo "  with:"
  echo "    creds: \${{ secrets.AZURE_CREDENTIALS }}"
  exit 0
fi

# Ensure git working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Please run this in a clean git workspace (no uncommitted changes). Aborting."
  exit 1
fi

# Create branch
git fetch origin
git checkout -b "$BRANCH_NAME"
echo "Created branch $BRANCH_NAME"

# Python snippet: load YAML, find azure/login@* step and replace its 'with' dict
echo "Patching $WORKFLOW_ABS to use AZURE_CREDENTIALS..."
python3 - <<'PY'
import sys, io, yaml, pathlib
p = pathlib.Path("<?WORKFLOW?>")
content = p.read_text()
data = yaml.safe_load(content)
changed = False

# Defensive checks
if not isinstance(data, dict):
    print("Unexpected workflow format", file=sys.stderr)
    sys.exit(1)

jobs = data.get("jobs", {})
deploy = jobs.get("deploy")
if not deploy:
    print("No 'deploy' job found; searching all jobs...", file=sys.stderr)
    # try all jobs
    jobs_to_check = jobs.values()
else:
    jobs_to_check = [deploy]

def update_steps(steps):
    global changed
    for step in steps:
        if isinstance(step, dict) and step.get("uses","").startswith("azure/login"):
            # Replace 'with' with single creds entry
            step["with"] = {"creds": "${{ secrets.AZURE_CREDENTIALS }}"}
            changed = True

# iterate jobs_to_check
if isinstance(jobs_to_check, list):
    for job in jobs_to_check:
        if not job:
            continue
        steps = job.get("steps")
        if isinstance(steps, list):
            update_steps(steps)
else:
    print("No steps found to update.", file=sys.stderr)

if not changed:
    print("Warning: Did not find any azure/login step to modify. Exiting without change.", file=sys.stderr)
    sys.exit(0)

# Write back preserving basic formatting
p.write_text(yaml.safe_dump(data, sort_keys=False))
print("Workflow file updated.")
PY
# Because we embedded the workflow path, patch it
# Replace placeholder with actual path and run the python script
# (we re-run a python command with the proper route; easier to rewrite above)
python3 - <<PY
import sys, pathlib, yaml
p = pathlib.Path("$WORKFLOW_ABS")
content = p.read_text()
data = yaml.safe_load(content)
changed = False

if not isinstance(data, dict):
    print("Unexpected workflow format", file=sys.stderr)
    sys.exit(1)

jobs = data.get("jobs", {})
# prefer 'deploy' job then fallback to all jobs
targets = []
if "deploy" in jobs:
    targets.append(jobs["deploy"])
else:
    targets.extend(jobs.values())

def update_steps(steps):
    global changed
    for step in steps:
        if isinstance(step, dict) and isinstance(step.get("uses"), str) and step.get("uses").startswith("azure/login"):
            step["with"] = {"creds": "${{ secrets.AZURE_CREDENTIALS }}"}
            changed = True

for job in targets:
    if not isinstance(job, dict):
        continue
    steps = job.get("steps")
    if isinstance(steps, list):
        update_steps(steps)

if not changed:
    print("No azure/login step found to change. Exiting without modifications.")
    sys.exit(0)

# Write YAML back
p.write_text(yaml.safe_dump(data, sort_keys=False))
print("Updated workflow file written to", p)
PY

# Stage, commit, push
git add "$WORKFLOW_ABS"
git commit -m "chore(workflow): use AZURE_CREDENTIALS secret for azure/login@v2"
git push --set-upstream origin "$BRANCH_NAME"

echo "Changes pushed to branch $BRANCH_NAME."

# 4) Create PR (optional)
if [ "$CREATE_PR" = true ]; then
  echo "Creating PR..."
  gh pr create --repo "$REPO" --title "$PR_TITLE" --body "$PR_BODY" --head "$BRANCH_NAME" --base main
  echo "PR created."
else
  echo "PR creation skipped (--no-pr)."
fi

echo "Done. CI should now be able to authenticate via azure/login@v2 using AZURE_CREDENTIALS."
echo
echo "Next steps:"
echo " - Wait for GitHub Actions run after PR merge, or run workflow manually."
echo " - If desired, remove the service principal when no longer needed:"
echo "     az ad sp delete --id <appId>"
