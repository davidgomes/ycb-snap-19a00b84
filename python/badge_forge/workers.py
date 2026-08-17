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
        badge_type = job.args["type"]
        company = job.args.get("company", "")

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Badge</title>
    <style>
        @page {{
            size: 4in 3in;
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
        .name {{
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 8px;
        }}
        .company {{
            font-size: 18px;
            color: #555;
        }}
        .badge-type {{
            font-size: 16px;
            font-weight: bold;
            text-transform: uppercase;
            padding: 6px 12px;
            background-color: #eee;
            border-radius: 4px;
            align-self: flex-start;
        }}
    </style>
</head>
<body>
    <div>
        <div class="name">{name}</div>
        <div class="company">{company}</div>
    </div>
    <div class="badge-type">{badge_type}</div>
</body>
</html>"""

        badge_path = f"/badges/{badge_id}.pdf"
        HTML(string=html_content).write_pdf(badge_path)

        logger.info(f"Badge generated: {badge_path}")
