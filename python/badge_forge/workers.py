import asyncio
import logging
import os
from html import escape
from pathlib import Path

from oban import Job, worker
from weasyprint import HTML

logger = logging.getLogger(__name__)

BADGE_OUTPUT_DIR = Path(os.environ.get("BADGE_OUTPUT_DIR", "/badges"))

BADGE_COLORS = {
    "attendee": "#2563eb",
    "speaker": "#7c3aed",
    "sponsor": "#059669",
    "organizer": "#dc2626",
}

BADGE_TEMPLATE = """
<html>
  <head>
    <style>
      @page {{
        size: 3.5in 5.5in;
        margin: 0;
      }}
      body {{
        margin: 0;
        font-family: "DejaVu Sans", sans-serif;
        color: #111827;
      }}
      .badge {{
        box-sizing: border-box;
        width: 100%;
        height: 100%;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        border: 4pt solid {color};
      }}
      .header {{
        background: {color};
        color: #ffffff;
        text-transform: uppercase;
        letter-spacing: 0.1em;
        text-align: center;
        font-size: 14pt;
        padding: 10pt 0;
      }}
      .body {{
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        text-align: center;
        padding: 12pt;
      }}
      .name {{
        font-size: 28pt;
        font-weight: bold;
        margin: 0 0 8pt 0;
      }}
      .company {{
        font-size: 16pt;
        color: #4b5563;
        margin: 0;
      }}
      .footer {{
        text-align: center;
        font-size: 8pt;
        color: #9ca3af;
        padding: 6pt 0;
      }}
    </style>
  </head>
  <body>
    <div class="badge">
      <div class="header">{badge_type}</div>
      <div class="body">
        <p class="name">{name}</p>
        <p class="company">{company}</p>
      </div>
      <div class="footer">{badge_id}</div>
    </div>
  </body>
</html>
"""


def _render_badge_pdf(badge_id: str, name: str, company: str, badge_type: str) -> Path:
    BADGE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    badge_path = BADGE_OUTPUT_DIR / f"{badge_id}.pdf"

    html = BADGE_TEMPLATE.format(
        badge_id=escape(badge_id),
        name=escape(name),
        company=escape(company),
        badge_type=escape(badge_type),
        color=BADGE_COLORS.get(badge_type, "#374151"),
    )

    HTML(string=html).write_pdf(badge_path)
    return badge_path


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        company = job.args.get("company", "")
        badge_type = job.args["type"]

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        badge_path = await asyncio.to_thread(
            _render_badge_pdf, badge_id, name, company, badge_type
        )

        logger.info(f"Badge generated: {badge_path}")
