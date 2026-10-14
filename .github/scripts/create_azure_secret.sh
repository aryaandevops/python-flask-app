#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="a66bdd02-2793-42a2-b680-feb23b03cdb7"
SP_NAME="raham"
REPO="devopsbyraham/python-flask-app"

if [[ -z "${GH_PAT:-}" ]]; then
  echo "Set GH_PAT to a GitHub PAT with repo admin access"
  exit 1
fi

# Prevent MSYS path conversion on Windows/Git Bash
if [[ -n "${MSYSTEM:-}" ]] || [[ "${OSTYPE:-}" == msys* ]] || [[ "${OSTYPE:-}" == cygwin* ]]; then
  export MSYS_NO_PATHCONV=1
  export MSYS2_ARG_CONV_EXCL="*"
fi

echo "==> Login to Azure"
az login
az account set --subscription "${SUBSCRIPTION_ID}"

echo "==> Create service principal and save SDK-auth JSON"
az ad sp create-for-rbac \
  --name "${SP_NAME}" \
  --role Contributor \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
  --sdk-auth > sp.json

jq -e '.clientId and .clientSecret and .tenantId and .subscriptionId' sp.json >/dev/null

echo "==> Validate SP role assignment"
CLIENT_ID=$(jq -r '.clientId' sp.json)
az ad sp show --id "${CLIENT_ID}" -o table
az role assignment list --assignee "${CLIENT_ID}" --scope "/subscriptions/${SUBSCRIPTION_ID}" -o table

echo "==> Add GitHub repo secret"
gh auth login --with-token <<< "${GH_PAT}"
gh secret set AZURE_CREDENTIALS --repo "${REPO}" --body "$(cat sp.json)"

echo "Done."
