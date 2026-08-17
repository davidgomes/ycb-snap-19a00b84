import html
import logging
from pathlib import Path

from oban import Job, worker
from weasyprint import HTML

logger = logging.getLogger(__name__)

BADGE_DIR = Path("/badges")

_TYPE_COLORS = {
    "attendee": "#2563eb",
    "speaker": "#7c3aed",
    "sponsor": "#b45309",
    "organizer": "#047857",
}


def _badge_html(name: str, company: str, badge_type: str, badge_id: str) -> str:
    accent = _TYPE_COLORS.get(badge_type, "#334155")
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    @page {{
      size: 4in 3in;
      margin: 0;
    }}
    html, body {{
      margin: 0;
      padding: 0;
      width: 4in;
      height: 3in;
      font-family: "DejaVu Sans", sans-serif;
    }}
    .badge {{
      box-sizing: border-box;
      width: 4in;
      height: 3in;
      padding: 0.28in 0.3in;
      border: 0.08in solid {accent};
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }}
    .event {{
      font-size: 11pt;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #64748b;
    }}
    .name {{
      font-size: 22pt;
      font-weight: 700;
      color: #0f172a;
      line-height: 1.15;
    }}
    .company {{
      font-size: 12pt;
      color: #334155;
    }}
    .footer {{
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }}
    .type {{
      background: {accent};
      color: #fff;
      font-size: 10pt;
      font-weight: 700;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      padding: 0.08in 0.14in;
    }}
    .id {{
      font-size: 8pt;
      color: #94a3b8;
    }}
  </style>
</head>
<body>
  <div class="badge">
    <div class="event">BadgeForge Conference</div>
    <div>
      <div class="name">{html.escape(name)}</div>
      <div class="company">{html.escape(company)}</div>
    </div>
    <div class="footer">
      <div class="type">{html.escape(badge_type)}</div>
      <div class="id">{html.escape(badge_id)}</div>
    </div>
  </div>
</body>
</html>
"""


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        company = job.args.get("company", "")
        badge_type = job.args["type"]

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        BADGE_DIR.mkdir(parents=True, exist_ok=True)
        badge_path = BADGE_DIR / f"{badge_id}.pdf"
        HTML(string=_badge_html(name, company, badge_type, badge_id)).write_pdf(badge_path)

        logger.info(f"Badge generated: {badge_path}")
