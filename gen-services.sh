#!/usr/bin/env bash
# Generate services dashboard HTML from nginx conf.d
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="$SCRIPT_DIR/services/nginx/conf.d"
OUTPUT="$SCRIPT_DIR/www/localhost/services.html"

# Use python3 to parse configs and generate JSON (reliable cross-platform)
json=$(python3 -c "
import glob, re, json, os

services = []
seen = set()

for conf in sorted(glob.glob('$CONF_DIR/*.conf')):
    filename = os.path.basename(conf).replace('.conf', '')
    content = open(conf).read()
    has_ssl = bool(re.search(r'listen\s+443\s+ssl|ssl_certificate\s', content))
    for m in re.findall(r'server_name\s+([^;]+);', content):
        for domain in m.split():
            if domain and domain not in seen:
                seen.add(domain)
                services.append({
                    'domain': domain,
                    'config': filename,
                    'scheme': 'https' if has_ssl else 'http'
                })

print(json.dumps(services))
")

cat > "$OUTPUT" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Local Services</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #0f172a; color: #e2e8f0; padding: 2rem;
    min-height: 100vh;
  }
  h1 { font-size: 1.5rem; margin-bottom: 1.5rem; color: #94a3b8; }
  h1 span { color: #38bdf8; }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 1rem;
  }
  .card {
    background: #1e293b; border-radius: 8px; padding: 1rem;
    border: 1px solid #334155; transition: border-color 0.2s;
  }
  .card:hover { border-color: #38bdf8; }
  .card-title {
    font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em;
    color: #64748b; margin-bottom: 0.75rem; font-weight: 600;
  }
  .domain-list { list-style: none; }
  .domain-list li { margin-bottom: 0.4rem; }
  .domain-list a {
    color: #38bdf8; text-decoration: none; font-size: 0.9rem;
    padding: 0.25rem 0.5rem; border-radius: 4px; display: inline-block;
    transition: background 0.2s;
  }
  .domain-list a:hover { background: #1e3a5f; }
  .badge {
    display: inline-block; font-size: 0.6rem; padding: 1px 5px;
    border-radius: 3px; margin-left: 0.4rem; vertical-align: middle;
    font-weight: 600;
  }
  .badge-ssl { background: #065f46; color: #6ee7b7; }
  .badge-http { background: #78350f; color: #fbbf24; }
  .stats { margin-bottom: 1.5rem; font-size: 0.85rem; color: #64748b; }
  .search {
    width: 100%; max-width: 400px; padding: 0.5rem 0.75rem;
    background: #1e293b; border: 1px solid #334155; border-radius: 6px;
    color: #e2e8f0; font-size: 0.9rem; margin-bottom: 1.5rem; outline: none;
  }
  .search:focus { border-color: #38bdf8; }
  .hidden { display: none; }
</style>
</head>
<body>
<h1><span>Local Services</span> Dashboard</h1>
<div class="stats" id="stats"></div>
<input type="text" class="search" placeholder="Filter domains..." id="search" autofocus>
<div class="grid" id="grid"></div>
<script>
const DATA = __JSON_DATA__;

const grouped = {};
DATA.forEach(s => {
  if (!grouped[s.config]) grouped[s.config] = [];
  grouped[s.config].push(s);
});
const configs = Object.keys(grouped).sort();

document.getElementById('stats').innerHTML =
  `${DATA.length} domains / ${configs.length} configs`;

const grid = document.getElementById('grid');
configs.forEach(config => {
  const items = grouped[config];
  const card = document.createElement('div');
  card.className = 'card';
  card.dataset.domains = items.map(s => s.domain).join(' ');
  card.innerHTML = `
    <div class="card-title">${config}.conf</div>
    <ul class="domain-list">
      ${items.map(s => `<li>
        <a href="${s.scheme}://${s.domain}" target="_blank">${s.domain}</a>
        <span class="badge ${s.scheme === 'https' ? 'badge-ssl' : 'badge-http'}">
          ${s.scheme === 'https' ? 'SSL' : 'HTTP'}
        </span>
      </li>`).join('')}
    </ul>`;
  grid.appendChild(card);
});

document.getElementById('search').addEventListener('input', function() {
  const q = this.value.toLowerCase();
  document.querySelectorAll('.card').forEach(card => {
    const match = card.dataset.domains.toLowerCase().includes(q) ||
                  card.querySelector('.card-title').textContent.toLowerCase().includes(q);
    card.classList.toggle('hidden', !match);
  });
});
</script>
</body>
</html>
HTMLEOF

# Inject JSON data into the HTML
python3 -c "
html = open('$OUTPUT').read()
html = html.replace('__JSON_DATA__', '''$json''')
open('$OUTPUT', 'w').write(html)
"

count=$(python3 -c "import json; print(len(json.loads('$json')))")
echo "Generated: $OUTPUT ($count domains)"
