"""Render conference badges to PDF with WeasyPrint."""

import os
import re
from html import escape
from pathlib import Path

from weasyprint import HTML

DEFAULT_OUTPUT_DIR = "/badges"

# Accent colour per badge type, so badges are sortable at a glance.
TYPE_COLORS = {
    "attendee": "#2563eb",
    "speaker": "#c2410c",
    "sponsor": "#7c3aed",
    "staff": "#047857",
    "volunteer": "#0e7490",
}
DEFAULT_TYPE_COLOR = "#334155"

_UNSAFE_FILENAME_CHARS = re.compile(r"[^A-Za-z0-9._-]")

STYLESHEET = """
@page {
  size: 4in 3in;
  margin: 0;
}

body {
  font-family: "Helvetica", "Arial", sans-serif;
  margin: 0;
  color: #0f172a;
}

.badge {
  box-sizing: border-box;
  height: 3in;
  width: 4in;
  display: flex;
  flex-direction: column;
}

.band {
  background: %(color)s;
  color: #ffffff;
  font-size: 11pt;
  font-weight: bold;
  letter-spacing: 0.18em;
  padding: 8pt 16pt;
  text-transform: uppercase;
}

.details {
  display: flex;
  flex-direction: column;
  flex-grow: 1;
  justify-content: center;
  padding: 12pt 16pt;
}

.name {
  font-size: %(name_size)spt;
  font-weight: bold;
  line-height: 1.1;
  word-wrap: break-word;
}

.company {
  color: #475569;
  font-size: 13pt;
  padding-top: 6pt;
}

.footer {
  border-top: 1pt solid #e2e8f0;
  color: #94a3b8;
  font-family: "DejaVu Sans Mono", monospace;
  font-size: 8pt;
  padding: 6pt 16pt;
}
"""


def _name_font_size(name: str) -> int:
    """Shrink the name so long ones still fit on a single badge."""
    if len(name) > 28:
        return 20
    if len(name) > 18:
        return 26
    return 34


def render_html(badge_id: str, name: str, badge_type: str, company: str | None = None) -> str:
    """Build the badge markup for a single attendee."""
    color = TYPE_COLORS.get(badge_type.lower(), DEFAULT_TYPE_COLOR)
    stylesheet = STYLESHEET % {"color": color, "name_size": _name_font_size(name)}
    company_html = f'<div class="company">{escape(company)}</div>' if company else ""

    return f"""<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>{escape(name)}</title>
    <style>{stylesheet}</style>
  </head>
  <body>
    <div class="badge">
      <div class="band">{escape(badge_type)}</div>
      <div class="details">
        <div class="name">{escape(name)}</div>
        {company_html}
      </div>
      <div class="footer">{escape(badge_id)}</div>
    </div>
  </body>
</html>
"""


def output_dir() -> Path:
    return Path(os.environ.get("BADGE_OUTPUT_DIR", DEFAULT_OUTPUT_DIR))


def generate_badge(
    badge_id: str,
    name: str,
    badge_type: str,
    company: str | None = None,
    directory: Path | None = None,
) -> Path:
    """Write the badge PDF to disk and return its path.

    Blocking: WeasyPrint renders synchronously, so callers in async code should
    hand this off to a thread.
    """
    directory = directory or output_dir()
    directory.mkdir(parents=True, exist_ok=True)

    path = directory / f"{_UNSAFE_FILENAME_CHARS.sub('-', str(badge_id))}.pdf"
    html = render_html(badge_id, name, badge_type, company)
    HTML(string=html).write_pdf(path)

    return path
