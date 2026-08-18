"""Badge PDF rendering."""

import logging
import os
from html import escape
from pathlib import Path

from weasyprint import HTML

# Both libraries narrate every render step at INFO, which buries the worker's
# own logs once a batch of badges is running.
logging.getLogger("weasyprint").setLevel(logging.WARNING)
logging.getLogger("fontTools").setLevel(logging.WARNING)

DEFAULT_OUTPUT_DIR = Path("badges")

ACCENTS = {
    "attendee": "#1d4ed8",
    "speaker": "#7c3aed",
    "sponsor": "#0f766e",
    "organizer": "#b91c1c",
}

FALLBACK_ACCENT = "#334155"

TEMPLATE = """<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>{name}</title>
    <style>
      @page {{
        size: 4in 3in;
        margin: 0;
      }}

      body {{
        color: #0f172a;
        font-family: Helvetica, Arial, sans-serif;
        margin: 0;
      }}

      /* A badge is always a single page, so clip anything that runs long. */
      .badge {{
        height: 3in;
        overflow: hidden;
        position: relative;
      }}

      .band {{
        background: {accent};
        color: #ffffff;
        font-size: 12pt;
        font-weight: bold;
        letter-spacing: 2pt;
        padding: 0.18in 0.25in;
        text-transform: uppercase;
      }}

      .holder {{
        padding: 0.3in 0.25in 0;
      }}

      .name {{
        font-size: {name_size}pt;
        font-weight: bold;
        line-height: 1.1;
        margin: 0;
        overflow-wrap: break-word;
      }}

      .company {{
        color: #475569;
        font-size: 13pt;
        margin: 0.12in 0 0;
        overflow-wrap: break-word;
      }}

      .footer {{
        border-top: 2pt solid {accent};
        bottom: 0;
        color: #64748b;
        font-size: 7pt;
        left: 0;
        letter-spacing: 1pt;
        padding: 0.1in 0.25in;
        position: absolute;
        right: 0;
      }}
    </style>
  </head>
  <body>
    <div class="badge">
      <div class="band">{badge_type}</div>
      <div class="holder">
        <p class="name">{name}</p>
        <p class="company">{company}</p>
      </div>
      <div class="footer">{badge_id}</div>
    </div>
  </body>
</html>
"""


def output_dir() -> Path:
    """Directory badge PDFs are written to."""

    return Path(os.environ.get("BADGE_OUTPUT_DIR") or DEFAULT_OUTPUT_DIR)


def name_size(name: str) -> int:
    """Point size that keeps a name from crowding out the rest of the badge."""

    if len(name) <= 20:
        return 34
    elif len(name) <= 32:
        return 26
    else:
        return 20


def render_html(badge_id: str, name: str, company: str, badge_type: str) -> str:
    """Build the badge markup for a single attendee."""

    return TEMPLATE.format(
        accent=ACCENTS.get(badge_type, FALLBACK_ACCENT),
        badge_id=escape(badge_id),
        badge_type=escape(badge_type),
        company=escape(company),
        name=escape(name),
        name_size=name_size(name),
    )


def render_pdf(
    badge_id: str,
    name: str,
    company: str,
    badge_type: str,
    directory: Path | None = None,
) -> Path:
    """Write a badge PDF and return its path.

    This is CPU bound and blocking, so it is meant to be called in a thread.
    """

    directory = directory or output_dir()
    directory.mkdir(parents=True, exist_ok=True)

    path = directory / f"{badge_id}.pdf"
    html = render_html(badge_id, name, company, badge_type)

    HTML(string=html).write_pdf(path)

    return path
