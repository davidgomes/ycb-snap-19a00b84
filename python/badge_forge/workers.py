import html as html_lib
import logging
from pathlib import Path

from oban import Job, worker
from weasyprint import HTML

logger = logging.getLogger(__name__)

BADGE_DIR = Path("/badges")

BADGE_COLORS = {
    "attendee": "#2563eb",
    "speaker": "#7c3aed",
    "sponsor": "#059669",
    "organizer": "#dc2626",
}


def _badge_html(name: str, company: str, badge_type: str) -> str:
    accent = BADGE_COLORS.get(badge_type, "#334155")
    safe_name = html_lib.escape(name)
    safe_company = html_lib.escape(company)
    safe_type = html_lib.escape(badge_type)
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    @page {{
      size: 4in 6in;
      margin: 0;
    }}
    html, body {{
      margin: 0;
      padding: 0;
      width: 4in;
      height: 6in;
      font-family: Helvetica, Arial, sans-serif;
    }}
    .badge {{
      box-sizing: border-box;
      width: 4in;
      height: 6in;
      padding: 0.4in;
      background: #0f172a;
      color: #f8fafc;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }}
    .header {{
      background: {accent};
      color: white;
      text-align: center;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      font-size: 18px;
      font-weight: bold;
      padding: 16px 8px;
      border-radius: 8px;
    }}
    .body {{
      flex: 1;
      display: flex;
      flex-direction: column;
      justify-content: center;
      text-align: center;
    }}
    .name {{
      font-size: 36px;
      font-weight: bold;
      line-height: 1.2;
      margin-bottom: 16px;
    }}
    .company {{
      font-size: 18px;
      color: #cbd5e1;
    }}
    .footer {{
      text-align: center;
      font-size: 12px;
      letter-spacing: 0.2em;
      text-transform: uppercase;
      color: #94a3b8;
    }}
  </style>
</head>
<body>
  <div class="badge">
    <div class="header">{safe_type}</div>
    <div class="body">
      <div class="name">{safe_name}</div>
      <div class="company">{safe_company}</div>
    </div>
    <div class="footer">BadgeForge</div>
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
        html = _badge_html(name, company, badge_type)
        HTML(string=html).write_pdf(badge_path)

        logger.info(f"Badge generated: {badge_path}")
