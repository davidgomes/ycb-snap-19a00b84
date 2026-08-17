import logging
from weasyprint import HTML

from oban import Job, worker

logger = logging.getLogger(__name__)


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        company = job.args.get("company", "")
        badge_type = job.args["type"]

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page {{
            size: 4in 6in;
            margin: 0;
        }}
        body {{
            font-family: sans-serif;
            margin: 0;
            padding: 24px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            box-sizing: border-box;
            height: 100%;
        }}
        .header {{
            text-align: center;
            font-size: 20px;
            font-weight: bold;
            color: #333;
        }}
        .content {{
            text-align: center;
            margin: auto 0;
        }}
        .name {{
            font-size: 32px;
            font-weight: bold;
            margin-bottom: 8px;
            color: #111;
        }}
        .company {{
            font-size: 20px;
            color: #555;
        }}
        .footer {{
            text-align: center;
            padding: 12px;
            background-color: #2563eb;
            color: white;
            font-size: 18px;
            font-weight: bold;
            text-transform: uppercase;
            border-radius: 6px;
        }}
    </style>
</head>
<body>
    <div class="header">BadgeForge Conf</div>
    <div class="content">
        <div class="name">{name}</div>
        <div class="company">{company}</div>
    </div>
    <div class="footer">{badge_type}</div>
</body>
</html>"""

        badge_path = f"/badges/{badge_id}.pdf"
        HTML(string=html_content).write_pdf(badge_path)

        logger.info(f"Badge generated: {badge_path}")

