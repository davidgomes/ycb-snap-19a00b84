import html
import logging
from pathlib import Path

from oban import Job, worker
import weasyprint

logger = logging.getLogger(__name__)

BADGE_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
@page {{
    size: 4in 6in;
    margin: 0;
}}
* {{
    box-sizing: border-box;
}}
body {{
    margin: 0;
    padding: 32px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #f8fafc;
    color: #0f172a;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    height: 100vh;
}}
.header {{
    text-align: center;
    border-bottom: 2px solid #e2e8f0;
    padding-bottom: 16px;
}}
.event-name {{
    font-size: 20px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 2px;
    color: #475569;
}}
.content {{
    text-align: center;
    margin: auto 0;
}}
.name {{
    font-size: 32px;
    font-weight: 800;
    line-height: 1.2;
    margin-bottom: 12px;
    color: #0f172a;
}}
.company {{
    font-size: 20px;
    font-weight: 500;
    color: #64748b;
}}
.footer {{
    text-align: center;
    padding-top: 16px;
}}
.badge-type {{
    display: inline-block;
    padding: 8px 24px;
    border-radius: 9999px;
    font-size: 16px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1.5px;
}}
.badge-attendee {{
    background-color: #e2e8f0;
    color: #334155;
}}
.badge-speaker {{
    background-color: #dbeafe;
    color: #1e40af;
}}
.badge-sponsor {{
    background-color: #fef3c7;
    color: #92400e;
}}
.badge-organizer {{
    background-color: #fce7f3;
    color: #9d174d;
}}
</style>
</head>
<body>
<div class="header">
    <div class="event-name">BadgeForge Conference</div>
</div>
<div class="content">
    <div class="name">{name}</div>
    {company_html}
</div>
<div class="footer">
    <div class="badge-type badge-{type_class}">{badge_type}</div>
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
        badge_type = job.args.get("type", "attendee")
        company = job.args.get("company", "")

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        badge_dir = Path("/badges")
        try:
            badge_dir.mkdir(parents=True, exist_ok=True)
            badge_path = badge_dir / f"{badge_id}.pdf"
        except (PermissionError, OSError):
            badge_dir = Path("/tmp/badges")
            badge_dir.mkdir(parents=True, exist_ok=True)
            badge_path = badge_dir / f"{badge_id}.pdf"

        company_html = (
            f'<div class="company">{html.escape(company)}</div>'
            if company
            else ""
        )
        type_class = html.escape(badge_type.lower())
        html_content = BADGE_TEMPLATE.format(
            name=html.escape(name),
            company_html=company_html,
            type_class=type_class,
            badge_type=html.escape(badge_type),
        )

        weasyprint.HTML(string=html_content).write_pdf(target=str(badge_path))

        logger.info(f"Badge generated: {badge_path}")
