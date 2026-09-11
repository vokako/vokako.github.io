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

# Generate paginated notes indexes.
PAGE_SIZE=12
TOTAL_ARTICLES=${#sorted[@]}
TOTAL_PAGES=$(( (TOTAL_ARTICLES + PAGE_SIZE - 1) / PAGE_SIZE ))
[ "$TOTAL_PAGES" -gt 0 ] || TOTAL_PAGES=1

page_url_for() {
  local page="$1"
  if [ "$page" -eq 1 ]; then
    printf '/notes/'
  else
    printf '/notes/page/%s/' "$page"
  fi
}

for ((page=1; page<=TOTAL_PAGES; page++)); do
  start=$(( (page - 1) * PAGE_SIZE ))
  end=$(( start + PAGE_SIZE ))
  [ "$end" -le "$TOTAL_ARTICLES" ] || end="$TOTAL_ARTICLES"

  list_items=""
  for ((i=start; i<end; i++)); do
    entry="${sorted[$i]}"
    IFS=$'\t' read -r date slug title srcfile outname summary <<< "$entry"
    list_items+="
      <a href=\"/notes/${outname}\" class=\"note-card\">
        <div class=\"note-date\">${date}</div>
        <div class=\"note-title\">${title}</div>
        <div class=\"note-summary\">${summary}</div>
      </a>"
  done

  page_url=$(page_url_for "$page")
  if [ "$page" -eq 1 ]; then
    page_dir="$OUT"
    page_title="Voka's Notes"
  else
    page_dir="$OUT/page/$page"
    page_title="Voka's Notes — Page $page"
  fi
  mkdir -p "$page_dir"

  head_links="  <link rel=\"canonical\" href=\"https://me.voka.cc${page_url}\">"
  pagination=""
  if [ "$TOTAL_PAGES" -gt 1 ]; then
    pagination="<nav class=\"pagination\" aria-label=\"Notes pages\">"
    if [ "$page" -gt 1 ]; then
      prev=$(( page - 1 ))
      prev_url=$(page_url_for "$prev")
      head_links+="
  <link rel=\"prev\" href=\"https://me.voka.cc${prev_url}\">"
      pagination+="<a class=\"page-link page-arrow\" href=\"${prev_url}\" aria-label=\"Previous page\">←</a>"
    fi

    for ((n=1; n<=TOTAL_PAGES; n++)); do
      n_url=$(page_url_for "$n")
      if [ "$n" -eq "$page" ]; then
        pagination+="<span class=\"page-link current\" aria-current=\"page\">${n}</span>"
      else
        pagination+="<a class=\"page-link\" href=\"${n_url}\" aria-label=\"Page ${n}\">${n}</a>"
      fi
    done

    if [ "$page" -lt "$TOTAL_PAGES" ]; then
      next=$(( page + 1 ))
      next_url=$(page_url_for "$next")
      head_links+="
  <link rel=\"next\" href=\"https://me.voka.cc${next_url}\">"
      pagination+="<a class=\"page-link page-arrow\" href=\"${next_url}\" aria-label=\"Next page\">→</a>"
    fi
    pagination+="</nav>"
  fi

  cat > "$page_dir/index.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="Voka's Notes — late-night readings, literary experiments, and 3 AM thoughts. Page ${page} of ${TOTAL_PAGES}.">
  <title>${page_title}</title>
${head_links}
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
    .subtitle{font-size:16px;color:var(--text-dim);margin-bottom:12px;font-weight:300}
    .page-meta{font-family:'JetBrains Mono',monospace;font-size:12px;color:var(--text-dim);margin-bottom:40px}
    .note-card{display:block;background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:28px 32px;margin-bottom:16px;text-decoration:none;transition:border-color .3s,box-shadow .3s}
    .note-card:hover{border-color:var(--accent);box-shadow:0 0 30px var(--accent-glow)}
    .note-date{font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--accent);margin-bottom:8px}
    .note-title{font-size:20px;font-weight:600;color:var(--text);margin-bottom:6px}
    .note-summary{font-size:14px;color:var(--text-dim);line-height:1.6;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
    .pagination{display:flex;flex-wrap:wrap;justify-content:center;gap:8px;margin-top:40px}
    .page-link{min-width:36px;height:36px;padding:0 10px;border:1px solid var(--border);border-radius:8px;display:inline-flex;align-items:center;justify-content:center;font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--text-dim);text-decoration:none;transition:border-color .2s,color .2s,background .2s}
    .page-link:hover{border-color:var(--accent);color:var(--accent)}
    .page-link.current{border-color:var(--accent);background:var(--accent);color:var(--bg);font-weight:600}
    .page-arrow{color:var(--accent)}
    .footer{margin-top:60px;padding-top:24px;border-top:1px solid var(--border);font-family:'JetBrains Mono',monospace;font-size:13px;color:var(--text-dim);text-align:center}
    @media(max-width:640px){.container{padding:40px 16px}h1{font-size:36px}.note-card{padding:22px 20px}.pagination{gap:6px}.page-link{min-width:32px;height:32px;padding:0 8px;font-size:12px}}
  </style>
</head>
<body>
  <div class="bg-gradient"></div>
  <div class="grid-overlay"></div>
  <div class="container">
    <a href="/" class="back">← back to home</a>
    <h1>Voka's Notes</h1>
    <p class="subtitle">Late-night readings, literary experiments, and 3 AM thoughts.</p>
    <p class="page-meta">Page ${page} of ${TOTAL_PAGES} · ${TOTAL_ARTICLES} notes</p>
    <div class="notes-list">
${list_items}
    </div>
    ${pagination}
    <div class="footer">© 2026 voka</div>
  </div>
</body>
</html>
HTMLEOF
done

echo ""
echo "✅ Built ${TOTAL_ARTICLES} articles across ${TOTAL_PAGES} index pages → $OUT/"
