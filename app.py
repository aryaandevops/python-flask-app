
from flask import Flask, jsonify, render_template_string, request
import os

app = Flask(__name__)
version = os.environ.get("APP_VERSION", "2.0.0")

MENU = [
    {
        "id": 1,
        "name": "Margherita Pizza",
        "description": "San Marzano tomatoes, fresh mozzarella, basil, extra-virgin olive oil",
        "price": 12.50,
        "tags": ["vegetarian"]
    },
    {
        "id": 2,
        "name": "Truffle Mushroom Risotto",
        "description": "Arborio rice, wild mushrooms, shaved parmesan, white truffle oil",
        "price": 18.00,
        "tags": ["gluten-free", "chef-special"]
    },
    {
        "id": 3,
        "name": "Seared Salmon",
        "description": "Pan-seared Atlantic salmon, lemon butter sauce, seasonal vegetables",
        "price": 20.00,
        "tags": ["fish"]
    },
    {
        "id": 4,
        "name": "Chocolate Lava Cake",
        "description": "Warm molten center, vanilla bean ice cream",
        "price": 8.00,
        "tags": ["dessert"]
    }
]

BASE_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Aryan Restaurant</title>

  <style>
    :root {
      --bg: #0f1724;
      --card: #0b1220;
      --muted: #9aa4b2;
      --accent: #ff7a59;
      --accent-2: #7ce7c6;
      color-scheme: dark;
      color: #e6eef6;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system,
                   "Segoe UI", Roboto, Arial, sans-serif;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      background: linear-gradient(180deg, #071426 0%, #081827 60%);
      min-height: 100vh;
    }

    .container {
      max-width: 1100px;
      margin: 32px auto;
      padding: 28px;
    }

    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 20px;
      gap: 16px;
    }

    .brand {
      display: flex;
      gap: 14px;
      align-items: center;
    }

    .logo {
      width: 56px;
      height: 56px;
      border-radius: 12px;
      background: linear-gradient(135deg, var(--accent), #ffb399);
      display: flex;
      align-items: center;
      justify-content: center;
      color: #0b1220;
      font-weight: 800;
      font-size: 24px;
    }

    h1 {
      margin: 0;
      font-size: 28px;
    }

    p.lead {
      margin: 8px 0 0;
      color: var(--muted);
    }

    .controls {
      display: flex;
      gap: 12px;
      align-items: center;
      flex-wrap: wrap;
    }

    button.cta {
      background: var(--accent);
      border: none;
      padding: 10px 14px;
      border-radius: 8px;
      color: #071426;
      font-weight: 700;
      cursor: pointer;
    }

    button.ghost {
      background: transparent;
      border: 1px solid rgba(255,255,255,0.15);
      padding: 8px 12px;
      border-radius: 8px;
      color: var(--muted);
      cursor: pointer;
    }

    .grid {
      display: grid;
      grid-template-columns: 1fr 360px;
      gap: 20px;
    }

    .menu {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
      gap: 16px;
    }

    .card {
      background: var(--card);
      padding: 16px;
      border-radius: 12px;
      box-shadow: 0 6px 20px rgba(2,6,23,0.6);
      border: 1px solid rgba(255,255,255,0.05);
    }

    .card h3 {
      margin: 0 0 8px;
    }

    .price {
      font-weight: 800;
      color: var(--accent-2);
    }

    .tags {
      color: var(--muted);
      font-size: 13px;
      margin-top: 8px;
    }

    aside .card {
      position: sticky;
      top: 28px;
    }

    .reserve-form input,
    .reserve-form textarea {
      width: 100%;
      padding: 10px;
      border-radius: 8px;
      border: 1px solid rgba(255,255,255,0.15);
      background: transparent;
      color: inherit;
      margin-bottom: 8px;
    }

    .reserve-form label {
      font-size: 13px;
      color: var(--muted);
      display: block;
    }

    footer {
      margin-top: 28px;
      color: var(--muted);
      text-align: center;
    }

    @media (max-width: 900px) {
      .grid {
        grid-template-columns: 1fr;
      }

      aside {
        order: 2;
      }

      header {
        flex-wrap: wrap;
      }
    }

    :root.light {
      --bg: #f6f8fb;
      --card: #ffffff;
      --muted: #475569;
      --accent: #ff6b4a;
      --accent-2: #0b9d84;
      color-scheme: light;
      color: #0b1220;
      background: linear-gradient(180deg, #ffffff 0%, #f1f5f9 60%);
    }
  </style>
</head>

<body>
  <div class="container">
    <header>
      <div class="brand">
        <div class="logo">A</div>
        <div>
          <h1>Aryan Restaurant</h1>
          <p class="lead">Seasonal, fresh, and chef-crafted meals</p>
        </div>
      </div>

      <div class="controls">
        <div style="text-align:right;color:var(--muted);font-size:13px">
          Version: {{ version }}
        </div>
        <button class="ghost" onclick="toggleTheme()">Toggle Theme</button>
        <button class="cta" onclick="scrollToReserve()">Reserve</button>
      </div>
    </header>

    <div class="grid">
      <main>
        <section class="card" style="margin-bottom:16px">
          <h2 style="margin-top:0">Welcome</h2>
          <p style="color:var(--muted)">
            Welcome to Aryan. Enjoy a curated selection of dishes crafted
            with seasonal ingredients. Browse the menu or reserve a table.
          </p>
        </section>

        <section>
          <h2 style="margin:6px 0 12px 8px">Menu</h2>

          <div id="menu" class="menu">
            {% for item in menu %}
            <div class="card">
              <h3>
                {{ item.name }}
                <span style="float:right" class="price">
                  ${{ '%.2f' % item.price }}
                </span>
              </h3>

              <div style="color:var(--muted);font-size:14px">
                {{ item.description }}
              </div>

              <div class="tags">
                {% for t in item.tags %}
                  <span>#{{ t }}</span>
                {% endfor %}
              </div>

              <div style="margin-top:12px;display:flex;
                          justify-content:space-between;align-items:center">
                <button class="cta" onclick="order({{ item.id }})">
                  Order
                </button>
                <button class="ghost" onclick="addToFavorites({{ item.id }})">
                  ♡ Favorite
                </button>
              </div>
            </div>
            {% endfor %}
          </div>
        </section>
      </main>

      <aside>
        <div class="card reserve-form">
          <h3>Reserve a table</h3>

          <label for="name">Name</label>
          <input id="name" placeholder="Your name">

          <label for="party">Party size</label>
          <input id="party" type="number" min="1" value="2">

          <label for="datetime">Date &amp; Time</label>
          <input id="datetime" type="datetime-local">

          <label for="notes">Notes</label>
          <textarea id="notes" rows="3"
                    placeholder="Allergies or requests"></textarea>

          <button class="cta" onclick="reserve()">
            Request Reservation
          </button>

          <div id="reserveStatus"
               style="margin-top:8px;color:var(--muted)"></div>
        </div>

        <div style="height:16px"></div>

        <div class="card">
          <h4 style="margin:0 0 8px">Favorites</h4>
          <div id="favorites" style="color:var(--muted)">
            No favorites yet
          </div>
        </div>
      </aside>
    </div>

    <footer>
      <div>© Aryan Restaurant • Built with Flask</div>
    </footer>
  </div>

  <script>
    const MENU = {{ menu|tojson }};
    let favorites = [];

    function order(id) {
      const item = MENU.find(x => x.id === id);

      if (item) {
        alert(
          'Order received for: ' + item.name +
          ' — Price: $' + item.price.toFixed(2)
        );
      }
    }

    function addToFavorites(id) {
      if (!favorites.includes(id)) {
        favorites.push(id);
      }

      renderFavorites();
    }

    function renderFavorites() {
      const el = document.getElementById('favorites');

      if (favorites.length === 0) {
        el.innerText = 'No favorites yet';
        return;
      }

      const names = favorites.map(
        id => (MENU.find(x => x.id === id) || {name: '?'}).name
      );

      el.innerHTML = names.map(
        n => '<div>• ' + n + '</div>'
      ).join('');
    }

    function reserve() {
      const name = document.getElementById('name').value.trim();
      const party = document.getElementById('party').value;
      const datetime = document.getElementById('datetime').value;
      const status = document.getElementById('reserveStatus');

      if (!name || !datetime) {
        status.innerText = 'Please enter name and date/time.';
        return;
      }

      status.innerText =
        `Reservation requested for ${name} (party of ${party}) at ${datetime}.`;

      setTimeout(() => {
        status.innerText =
          'Reservation request sent — we will confirm shortly.';
      }, 1200);
    }

    function toggleTheme() {
      document.documentElement.classList.toggle('light');
    }

    function scrollToReserve() {
      document.querySelector('.reserve-form').scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });
    }

    try {
      const raw = localStorage.getItem('aryan.favs');

      if (raw) {
        favorites = JSON.parse(raw);
      }

      renderFavorites();
    } catch (e) {
      console.warn(e);
    }

    window.addEventListener('beforeunload', () => {
      localStorage.setItem('aryan.favs', JSON.stringify(favorites));
    });
  </script>
</body>
</html>
"""


@app.route("/")
def home_ui():
    return render_template_string(
        BASE_TEMPLATE,
        menu=MENU,
        version=version
    )


@app.route("/health")
def health_check():
    return jsonify({"status": "healthy", "version": version}), 200


@app.route("/api/menu")
def api_menu():
    return jsonify({"menu": MENU, "version": version}), 200


@app.route("/api/reserve", methods=["POST"])
def api_reserve():
    data = request.get_json() or {}

    name = data.get("name")
    party = data.get("party")
    datetime_value = data.get("datetime")
    notes = data.get("notes")

    if not name or not datetime_value:
        return jsonify({"error": "name and datetime required"}), 400

    confirmation = {
        "status": "requested",
        "name": name,
        "party": party,
        "datetime": datetime_value,
        "notes": notes,
        "version": version
    }

    return jsonify(confirmation), 201


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
