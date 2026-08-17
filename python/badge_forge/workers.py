import logging
from pathlib import Path
from string import Template

from oban import Job, worker
from weasyprint import HTML

logger = logging.getLogger(__name__)

BADGE_DIR = Path("/badges")

BADGE_HTML = Template("""\
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    @page { size: 4in 3in; margin: 0; }
    body {
      margin: 0;
      font-family: Helvetica, Arial, sans-serif;
    }
    .badge {
      box-sizing: border-box;
      width: 4in;
      height: 3in;
      padding: 0.35in;
      border-top: 0.28in solid $accent;
      background: #f7f7f4;
      color: #1a1a1a;
    }
    .type {
      font-size: 11pt;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: $accent;
      margin: 0 0 0.2in;
    }
    .name {
      font-size: 22pt;
      font-weight: 700;
      margin: 0 0 0.08in;
      line-height: 1.15;
    }
    .company {
      font-size: 13pt;
      color: #444;
      margin: 0;
    }
  </style>
</head>
<body>
  <div class="badge">
    <p class="type">$badge_type</p>
    <p class="name">$name</p>
    <p class="company">$company</p>
  </div>
</body>
</html>
""")

ACCENTS = {
    "speaker": "#b45309",
    "sponsor": "#1d4ed8",
    "organizer": "#166534",
    "attendee": "#334155",
}


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        badge_type = job.args["type"]
        company = job.args.get("company", "")

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        BADGE_DIR.mkdir(parents=True, exist_ok=True)
        badge_path = BADGE_DIR / f"{badge_id}.pdf"
        html = BADGE_HTML.substitute(
            name=_escape(name),
            company=_escape(company),
            badge_type=_escape(badge_type),
            accent=ACCENTS.get(badge_type, ACCENTS["attendee"]),
        )
        HTML(string=html).write_pdf(badge_path)

        logger.info(f"Badge generated: {badge_path}")


def _escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )
