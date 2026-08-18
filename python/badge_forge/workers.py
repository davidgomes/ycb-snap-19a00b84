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
</head>
<body>
    <div class="badge">
        <h1>{name}</h1>
        <p class="company">{company}</p>
        <p class="type">{badge_type}</p>
    </div>
</body>
</html>"""

        badge_path = f"/badges/{badge_id}.pdf"
        HTML(string=html_content).write_pdf(badge_path)

        logger.info(f"Badge generated: {badge_path}")

