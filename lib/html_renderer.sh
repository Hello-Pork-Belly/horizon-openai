#!/usr/bin/env bash
set -euo pipefail

# lib/html_renderer.sh
# Render phase report JSONL into a static HTML file.

html__log_info() { command -v log_info >/dev/null 2>&1 && log_info "$@" || echo "INFO: $*"; }
html__log_error() { command -v log_error >/dev/null 2>&1 && log_error "$@" || echo "ERROR: $*" >&2; }

html_find_latest_jsonl() {
  local root latest=""
  if declare -F hz_repo_root >/dev/null 2>&1; then
    root="$(hz_repo_root)"
  else
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  [[ -d "${root}/records" ]] || return 1

  latest="$(find "${root}/records" -type f -name "*.report.jsonl" -print0 2>/dev/null | xargs -0 ls -1t 2>/dev/null | head -n 1 || true)"
  [[ -n "$latest" ]] || return 1
  printf '%s\n' "$latest"
}

html_render_report() {
  local jsonl="${1:-}"
  local out_html="${2:-}"

  [[ -n "$jsonl" ]] || { html__log_error "missing jsonl path"; return 1; }
  [[ -f "$jsonl" ]] || { html__log_error "jsonl not found: ${jsonl}"; return 1; }
  [[ -n "$out_html" ]] || { html__log_error "missing output html path"; return 1; }

  command -v python3 >/dev/null 2>&1 || {
    html__log_error "python3 not found"
    return 1
  }

  python3 - "$jsonl" "$out_html" <<'PY'
import datetime
import html
import json
import sys

src = sys.argv[1]
out = sys.argv[2]

rows = []
with open(src, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        rows.append({
            "target": str(obj.get("target", "")),
            "status": str(obj.get("status", "")),
            "duration_s": str(obj.get("duration_s", obj.get("duration", ""))),
            "message": str(obj.get("message", "")),
            "logfile": str(obj.get("logfile", obj.get("log", ""))),
        })

def status_class(status: str) -> str:
    s = (status or "").upper()
    if s in {"SUCCESS", "OK", "PASSED"}:
        return "st-ok"
    if s in {"FAILURE", "FAILED", "ERROR"}:
        return "st-bad"
    if s == "TIMEOUT":
        return "st-timeout"
    if s in {"ABORTED", "CANCELLED"}:
        return "st-abort"
    return "st-unk"

title = f"Horizon Report - {src}"
generated_at = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

doc = []
doc.append("<!doctype html><html><head><meta charset='utf-8'>")
doc.append("<meta name='viewport' content='width=device-width, initial-scale=1'>")
doc.append(f"<title>{html.escape(title)}</title>")
doc.append(
    """
<style>
  :root{
    --bg:#0b0f14; --panel:#101826; --text:#e6edf3; --muted:#9aa4af;
    --ok:#2ea043; --bad:#f85149; --warn:#d29922; --info:#58a6ff; --border:#223044;
  }
  body{margin:0;background:var(--bg);color:var(--text);font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial;}
  .wrap{max-width:1100px;margin:0 auto;padding:24px;}
  .hdr{display:flex;align-items:flex-end;justify-content:space-between;gap:12px;margin-bottom:16px;}
  h1{font-size:18px;margin:0;}
  .meta{color:var(--muted);font-size:12px;}
  .card{background:var(--panel);border:1px solid var(--border);border-radius:12px;overflow:hidden;}
  table{width:100%;border-collapse:collapse;}
  th,td{padding:12px 14px;border-bottom:1px solid var(--border);vertical-align:top;}
  th{color:var(--muted);text-align:left;font-size:12px;letter-spacing:.03em;text-transform:uppercase;}
  tr:hover td{background:rgba(255,255,255,.02);}
  .st{font-weight:700;}
  .st-ok{color:var(--ok);}
  .st-bad{color:var(--bad);}
  .st-timeout{color:var(--warn);}
  .st-abort{color:var(--info);}
  .st-unk{color:var(--muted);}
  .mono{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,Liberation Mono,Courier New,monospace;font-size:12px;color:var(--muted);}
  .msg{white-space:pre-wrap;word-break:break-word;}
  .footer{margin-top:10px;color:var(--muted);font-size:12px;}
  .pill{display:inline-block;padding:2px 8px;border:1px solid var(--border);border-radius:999px;color:var(--muted);font-size:12px;}
</style>
"""
)
doc.append("</head><body><div class='wrap'>")
doc.append("<div class='hdr'>")
doc.append(f"<div><h1>{html.escape(title)}</h1><div class='meta'>Generated at {html.escape(generated_at)}</div></div>")
doc.append(f"<div class='pill'>Rows: {len(rows)}</div>")
doc.append("</div>")
doc.append("<div class='card'><table>")
doc.append("<thead><tr><th>Target</th><th>Status</th><th>Duration</th><th>Message</th><th>Log</th></tr></thead><tbody>")

for row in rows:
    target = html.escape(row["target"])
    status = html.escape(row["status"])
    duration = html.escape(row["duration_s"])
    message = html.escape(row["message"])
    logfile = html.escape(row["logfile"])
    cls = status_class(row["status"])
    log_cell = f"<span class='mono'>{logfile}</span>" if logfile else "<span class='mono'>-</span>"
    doc.append(
        f"<tr><td class='mono'>{target}</td><td class='st {cls}'>{status}</td><td class='mono'>{duration}</td><td class='msg'>{message}</td><td>{log_cell}</td></tr>"
    )

doc.append("</tbody></table></div>")
doc.append("<div class='footer'>Secrets are never rendered in the dashboard output.</div>")
doc.append("</div></body></html>")

with open(out, "w", encoding="utf-8") as f:
    f.write("".join(doc))
PY
}
