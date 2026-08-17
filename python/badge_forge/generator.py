import logging
from pathlib import Path
from string.templatelib import Template

from oban import Job, worker
from weasyprint import HTML

logger = logging.getLogger(__name__)

BADGES_DIR = Path(__file__).parent.parent.parent / "priv" / "static" / "badges"


def render_badge_html(name: str, company: str, badge_type: str) -> str:
    template: Template = t"""<!DOCTYPE html>
<html>
<head>
    <style>
        body {
            font-family: system-ui, sans-serif;
            width: 4in;
            height: 3in;
            margin: 0;
            padding: 0.5in;
            box-sizing: border-box;
            display: flex;
            flex-direction: column;
        }
        .event {
            font-size: 12pt;
            color: #666;
            margin-bottom: 0.25in;
        }
        .name {
            font-size: 24pt;
            font-weight: bold;
            margin-bottom: 0.1in;
        }
        .company {
            font-size: 14pt;
            color: #444;
            margin-bottom: auto;
        }
        .type {
            font-size: 11pt;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            padding: 0.1in 0.2in;
            background: #333;
            color: white;
            align-self: flex-start;
        }
    </style>
</head>
<body>
    <div class="event">Oban Conf 2025 — Edinburgh</div>
    <div class="name">{name}</div>
    <div class="company">{company}</div>
    <div class="type">{badge_type}</div>
</body>
</html>"""

    return str(template)


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        company = job.args["company"]
        badge_type = job.args["type"]

        logger.info(f"Generating badge for {name} ({badge_type})")

        html = render_badge_html(name, company, badge_type)
        badge_path = BADGES_DIR / f"{badge_id}.pdf"

        HTML(string=html).write_pdf(badge_path)

        logger.info(f"Badge generated: {badge_path}")
