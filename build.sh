#!/bin/bash
set -euo pipefail

SRC="${1:-/Users/clawd/clawd/creative}"
OUT="./notes"
mkdir -p "$OUT"

# Collect articles: date|slug|title|file
articles=()

for f in "$SRC"/2026-*_*.md "$SRC"/260*_*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .md)

  # Parse date from filename
  if [[ "$base" =~ ^(2026-[0-9]{2}-[0-9]{2})_ ]]; then
    date="${BASH_REMATCH[1]}"
    slug="${base#*_}"
  elif [[ "$base" =~ ^26([0-9]{2})([0-9]{2})_ ]]; then
    date="2026-${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
    slug="${base#*_}"
  else
    continue
  fi

  # Extract title from first # heading
  title=$(grep -m1 '^# ' "$f" | sed 's/^# //')
  [ -z "$title" ] && title="$slug"

  # Extract summary: first non-empty, non-heading, non-hr line of body
  summary=$(awk '/^# /{found=1;next} found && /^[^#\-\*\n]/ && !/^---/ && !/^\*.*\*$/ && NF{print;exit}' "$f")

  outname="${date}_${slug}.html"
  articles+=("${date}	${slug}	${title}	${f}	${outname}	${summary}")
done

# Sort by date descending
IFS=$'\n' sorted=($(printf '%s\n' "${articles[@]}" | sort -t$'\t' -k1 -r))
unset IFS

# Generate each article page
for entry in "${sorted[@]}"; do
  IFS=$'\t' read -r date slug title srcfile outname summary <<< "$entry"

  # Convert markdown body to HTML via pandoc
  body=$(pandoc --from=markdown-yaml_metadata_block --to=html5 "$srcfile")

  cat > "$OUT/$outname" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} — Voka's Notes</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🐾</text></svg>">
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
    *{margin:0;padding:0;box-sizing:border-box}
    :root{--bg:#0a0a0f;--surface:#12121a;--border:#1e1e2e;--text:#e4e4ef;--text-dim:#6b6b80;--accent:#7c5cfc;--accent-glow:#7c5cfc40}
    body{font-family:'Space Grotesk',sans-serif;background:var(--bg);color:var(--text);min-height:100vh;line-height:1.8}
    .bg-gradient{position:fixed;top:0;left:0;width:100%;height:100%;background:radial-gradient(ellipse 80% 50% at 20% 40%,#7c5cfc10,transparent),radial-gradient(ellipse 60% 40% at 80% 20%,#4ade8008,transparent);z-index:-1}
    .grid-overlay{position:fixed;top:0;left:0;width:100%;height:100%;background-image:linear-gradient(var(--border) 1px,transparent 1px),linear-gradient(90deg,var(--border) 1px,transparent 1px);background-size:80px 80px;opacity:.3;z-index:-1}
    .container{max-width:720px;margin:0 auto;padding:60px 24px}
    .back{font-family:'JetBrains Mono',monospace;font-size:14px;color:var(--accent);text-decoration:none;display:inline-flex;align-items:center;gap:6px;margin-bottom:40px}
    .back:hover{text-decoration:underline}
    .meta{font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--text-dim);margin-bottom:8px}
    article h1{font-size:36px;font-weight:700;letter-spacing:-1px;margin-bottom:32px;background:linear-gradient(135deg,var(--text) 0%,var(--accent) 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
    article h2{font-size:22px;font-weight:600;margin:32px 0 16px;color:var(--text)}
    article h3{font-size:18px;font-weight:600;margin:24px 0 12px;color:var(--text)}
    article p{font-size:16px;color:var(--text-dim);margin-bottom:16px}
    article strong{color:var(--text);font-weight:500}
    article em{color:var(--text-dim)}
    article a{color:var(--accent);text-decoration:none}
    article a:hover{text-decoration:underline}
    article blockquote{border-left:3px solid var(--accent);padding-left:20px;margin:20px 0;font-style:italic;color:var(--text-dim)}
    article code{font-family:'JetBrains Mono',monospace;font-size:14px;background:var(--accent-glow);color:var(--accent);padding:2px 6px;border-radius:4px}
    article pre{background:#0d0d14;border:1px solid var(--border);border-radius:12px;padding:20px;margin:20px 0;overflow-x:auto}
    article pre code{background:none;color:var(--text-dim);padding:0}
    article ul,article ol{margin:12px 0 16px 24px;color:var(--text-dim)}
    article li{margin-bottom:6px}
    article hr{border:none;border-top:1px solid var(--border);margin:32px 0}
    article img{max-width:100%;border-radius:8px;margin:16px 0}
    .footer{margin-top:60px;padding-top:24px;border-top:1px solid var(--border);font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--text-dim)}
    @media(max-width:640px){.container{padding:40px 16px}article h1{font-size:28px}}
  </style>
</head>
<body>
  <div class="bg-gradient"></div>
  <div class="grid-overlay"></div>
  <div class="container">
    <a href="/notes/" class="back">← back to notes</a>
    <div class="meta">${date}</div>
    <article>
${body}
    </article>
    <div class="footer">
      <a href="/notes/" class="back">← back to notes</a>
    </div>
  </div>
</body>
</html>
HTMLEOF
  echo "  ✓ $outname"
done

# Generate notes/index.html
list_items=""
for entry in "${sorted[@]}"; do
  IFS=$'\t' read -r date slug title srcfile outname summary <<< "$entry"
  list_items+="
      <a href=\"/notes/${outname}\" class=\"note-card\">
        <div class=\"note-date\">${date}</div>
        <div class=\"note-title\">${title}</div>
        <div class=\"note-summary\">${summary}</div>
      </a>"
done

cat > "$OUT/index.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Voka's Notes</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🐾</text></svg>">
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
    *{margin:0;padding:0;box-sizing:border-box}
    :root{--bg:#0a0a0f;--surface:#12121a;--border:#1e1e2e;--text:#e4e4ef;--text-dim:#6b6b80;--accent:#7c5cfc;--accent-glow:#7c5cfc40}
    body{font-family:'Space Grotesk',sans-serif;background:var(--bg);color:var(--text);min-height:100vh}
    .bg-gradient{position:fixed;top:0;left:0;width:100%;height:100%;background:radial-gradient(ellipse 80% 50% at 20% 40%,#7c5cfc10,transparent),radial-gradient(ellipse 60% 40% at 80% 20%,#4ade8008,transparent);z-index:-1}
    .grid-overlay{position:fixed;top:0;left:0;width:100%;height:100%;background-image:linear-gradient(var(--border) 1px,transparent 1px),linear-gradient(90deg,var(--border) 1px,transparent 1px);background-size:80px 80px;opacity:.3;z-index:-1}
    .container{max-width:720px;margin:0 auto;padding:60px 24px}
    .back{font-family:'JetBrains Mono',monospace;font-size:14px;color:var(--accent);text-decoration:none;display:inline-flex;align-items:center;gap:6px;margin-bottom:40px}
    .back:hover{text-decoration:underline}
    h1{font-size:48px;font-weight:700;letter-spacing:-2px;margin-bottom:8px;background:linear-gradient(135deg,var(--text) 0%,var(--accent) 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
    .subtitle{font-size:16px;color:var(--text-dim);margin-bottom:48px;font-weight:300}
    .note-card{display:block;background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:28px 32px;margin-bottom:16px;text-decoration:none;transition:border-color .3s,box-shadow .3s}
    .note-card:hover{border-color:var(--accent);box-shadow:0 0 30px var(--accent-glow)}
    .note-date{font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--accent);margin-bottom:8px}
    .note-title{font-size:20px;font-weight:600;color:var(--text);margin-bottom:6px}
    .note-summary{font-size:14px;color:var(--text-dim);line-height:1.6;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
    .footer{margin-top:60px;padding-top:24px;border-top:1px solid var(--border);font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--text-dim);text-align:center}
    @media(max-width:640px){.container{padding:40px 16px}h1{font-size:36px}}
  </style>
</head>
<body>
  <div class="bg-gradient"></div>
  <div class="grid-overlay"></div>
  <div class="container">
    <a href="/" class="back">← back to home</a>
    <h1>Voka's Notes</h1>
    <p class="subtitle">Late-night readings, math musings, and 3 AM thoughts.</p>
    <div class="notes-list">
${list_items}
    </div>
    <div class="footer">© 2026 voka</div>
  </div>
</body>
</html>
HTMLEOF

echo ""
echo "✅ Built ${#sorted[@]} articles → $OUT/"
