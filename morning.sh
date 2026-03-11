#!/bin/bash
# Morning Report — generates an HTML summary of overnight work
# Usage: ./morning.sh                    (prints to stdout)
#        ./morning.sh > report.html      (save to file)
#        open $(./morning.sh --file)     (generate + open in browser)

cd "$(dirname "$0")"

if [ "$1" = "--file" ]; then
    ./morning.sh > output/morning_report.html
    echo "output/morning_report.html"
    exit 0
fi

# Detect the base branch (what we branched from)
BASE_BRANCH="main"
if git merge-base --is-ancestor main HEAD 2>/dev/null; then
    BASE_BRANCH="main"
elif git merge-base --is-ancestor ui HEAD 2>/dev/null; then
    BASE_BRANCH="ui"
fi

CURRENT_BRANCH=$(git branch --show-current)
COMMIT_COUNT=$(git rev-list --count "$BASE_BRANCH"..HEAD 2>/dev/null || echo "?")
FILES_CHANGED=$(git diff --stat "$BASE_BRANCH"..HEAD 2>/dev/null | tail -1)
COMMITS=$(git log --oneline "$BASE_BRANCH"..HEAD 2>/dev/null)

# Read task statuses from prd.json
TASK_ROWS=$(python3 -c "
import json, html
with open('prd.json') as f:
    data = json.load(f)
for t in data['tasks']:
    status = t.get('passes')
    if status is True:
        badge = '<span class=\"badge done\">Done</span>'
        row_class = 'row-done'
    elif status == 'blocked':
        reason = html.escape(t.get('blocked_reason', 'Unknown'))
        badge = f'<span class=\"badge blocked\" title=\"{reason}\">Blocked</span>'
        row_class = 'row-blocked'
    else:
        badge = '<span class=\"badge todo\">To Do</span>'
        row_class = 'row-todo'
    title = html.escape(t['title'])
    model = t.get('model', 'sonnet')
    print(f'<tr class=\"{row_class}\"><td>{t[\"id\"]}</td><td>{title}</td><td><code>{model}</code></td><td>{badge}</td></tr>')
" 2>/dev/null)

DONE_COUNT=$(python3 -c "
import json
with open('prd.json') as f: data = json.load(f)
print(sum(1 for t in data['tasks'] if t.get('passes') is True))
" 2>/dev/null || echo "?")

BLOCKED_COUNT=$(python3 -c "
import json
with open('prd.json') as f: data = json.load(f)
print(sum(1 for t in data['tasks'] if t.get('passes') == 'blocked'))
" 2>/dev/null || echo "0")

TOTAL_COUNT=$(python3 -c "
import json
with open('prd.json') as f: data = json.load(f)
print(len(data['tasks']))
" 2>/dev/null || echo "?")

TODO_COUNT=$(python3 -c "
import json
with open('prd.json') as f: data = json.load(f)
print(sum(1 for t in data['tasks'] if t.get('passes') is False))
" 2>/dev/null || echo "?")

# Read progress.txt
PROGRESS_CONTENT=$(cat progress.txt 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

# Build per-commit diffs
DIFF_SECTIONS=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    HASH=$(echo "$line" | awk '{print $1}')
    MSG=$(echo "$line" | cut -d' ' -f2-)
    MSG_ESCAPED=$(echo "$MSG" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    DIFF_STAT=$(git diff-tree --stat --no-commit-id "$HASH" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    DIFF_PATCH=$(git diff-tree -p --no-commit-id "$HASH" 2>/dev/null | head -200 | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    DIFF_SECTIONS="$DIFF_SECTIONS
<details class=\"commit-detail\">
<summary><code>$HASH</code> $MSG_ESCAPED</summary>
<div class=\"diff-stat\"><pre>$DIFF_STAT</pre></div>
<div class=\"diff-patch\"><pre>$DIFF_PATCH</pre></div>
</details>"
done <<< "$COMMITS"

cat <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Morning Report — $(date '+%b %d, %Y')</title>
<style>
  :root { --bg: #0d1117; --bg2: #161b22; --bg3: #21262d; --text: #e6edf3; --text2: #8b949e; --green: #3fb950; --red: #f85149; --yellow: #d29922; --blue: #58a6ff; --border: #30363d; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: var(--bg); color: var(--text); padding: 24px; max-width: 960px; margin: 0 auto; line-height: 1.5; }
  h1 { font-size: 24px; margin-bottom: 4px; }
  .subtitle { color: var(--text2); font-size: 14px; margin-bottom: 24px; }
  .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; margin-bottom: 24px; }
  .card { background: var(--bg2); border: 1px solid var(--border); border-radius: 8px; padding: 16px; }
  .card-label { font-size: 11px; color: var(--text2); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 4px; }
  .card-value { font-size: 28px; font-weight: 700; }
  .card-value.green { color: var(--green); }
  .card-value.yellow { color: var(--yellow); }
  .card-value.red { color: var(--red); }
  .card-value.blue { color: var(--blue); }
  h2 { font-size: 18px; margin: 24px 0 12px; border-bottom: 1px solid var(--border); padding-bottom: 8px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
  th { text-align: left; padding: 8px 12px; font-size: 12px; color: var(--text2); text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 1px solid var(--border); }
  td { padding: 8px 12px; border-bottom: 1px solid var(--border); font-size: 14px; }
  .row-done { background: rgba(63,185,80,0.05); }
  .row-blocked { background: rgba(248,81,73,0.05); }
  .row-todo { opacity: 0.5; }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
  .badge.done { background: rgba(63,185,80,0.15); color: var(--green); }
  .badge.blocked { background: rgba(248,81,73,0.15); color: var(--red); }
  .badge.todo { background: rgba(139,148,158,0.15); color: var(--text2); }
  code { background: var(--bg3); padding: 2px 6px; border-radius: 4px; font-size: 12px; }
  .commit-detail { background: var(--bg2); border: 1px solid var(--border); border-radius: 8px; margin-bottom: 8px; }
  .commit-detail summary { padding: 10px 14px; cursor: pointer; font-size: 13px; }
  .commit-detail summary:hover { background: var(--bg3); }
  .diff-stat pre, .diff-patch pre { padding: 12px 14px; font-size: 12px; overflow-x: auto; white-space: pre-wrap; word-break: break-all; color: var(--text2); }
  .diff-stat { border-top: 1px solid var(--border); background: var(--bg); }
  .diff-patch { border-top: 1px solid var(--border); background: var(--bg); max-height: 400px; overflow-y: auto; }
  .progress-log { background: var(--bg2); border: 1px solid var(--border); border-radius: 8px; padding: 16px; }
  .progress-log pre { font-size: 12px; white-space: pre-wrap; color: var(--text2); line-height: 1.6; }
  .tip { background: rgba(88,166,255,0.1); border: 1px solid rgba(88,166,255,0.2); border-radius: 8px; padding: 12px 16px; font-size: 13px; color: var(--blue); margin-bottom: 24px; }
  .tip code { color: var(--text); }
</style>
</head>
<body>

<h1>Morning Report</h1>
<p class="subtitle">Branch <code>$CURRENT_BRANCH</code> vs <code>$BASE_BRANCH</code> — generated $(date '+%b %d, %Y at %I:%M %p')</p>

<div class="tip">
  Quick commands: <code>git log --oneline $BASE_BRANCH..HEAD</code> to see commits,
  <code>git diff $BASE_BRANCH..HEAD -- app/index.html</code> to see specific file changes,
  <code>git revert &lt;hash&gt;</code> to undo a specific task
</div>

<div class="cards">
  <div class="card"><div class="card-label">Completed</div><div class="card-value green">$DONE_COUNT</div></div>
  <div class="card"><div class="card-label">Blocked</div><div class="card-value red">$BLOCKED_COUNT</div></div>
  <div class="card"><div class="card-label">Remaining</div><div class="card-value yellow">$TODO_COUNT</div></div>
  <div class="card"><div class="card-label">Commits</div><div class="card-value blue">$COMMIT_COUNT</div></div>
</div>

<h2>Task Board</h2>
<table>
  <thead><tr><th>#</th><th>Task</th><th>Model</th><th>Status</th></tr></thead>
  <tbody>
    $TASK_ROWS
  </tbody>
</table>

<h2>Commits — click to expand diffs</h2>
$DIFF_SECTIONS

<h2>Progress Log</h2>
<div class="progress-log"><pre>$PROGRESS_CONTENT</pre></div>

<h2>Overall Diff</h2>
<div class="commit-detail" open>
<summary><strong>$FILES_CHANGED</strong></summary>
<div class="diff-stat"><pre>$(git diff --stat "$BASE_BRANCH"..HEAD 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</pre></div>
</div>

</body>
</html>
HTMLEOF
