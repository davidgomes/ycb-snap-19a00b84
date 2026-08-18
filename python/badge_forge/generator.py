"""Generate conference badges from jobs enqueued by the Elixir app."""

import asyncio
import html
import os
from pathlib import Path

from oban import Job, worker

BADGES_DIR = Path(os.getenv("BADGES_DIR", Path(__file__).parents[1] / "badges"))

BADGE_TEMPLATE = """\
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{name} — BadgeForge</title>
    <style>
      body {{ font-family: sans-serif; margin: 0; }}
      .badge {{ box-sizing: border-box; height: 4in; padding: .4in; text-align: center; width: 3in; }}
      .type {{ letter-spacing: .1em; text-transform: uppercase; }}
      .name {{ font-size: 28pt; margin: .3in 0 .1in; }}
      .company {{ color: #444; font-size: 16pt; }}
    </style>
  </head>
  <body>
    <main class="badge {type}">
      <p class="type">{type}</p>
      <h1 class="name">{name}</h1>
      <p class="company">{company}</p>
    </main>
  </body>
</html>
"""


def render_badge(args: dict) -> str:
    """Render escaped badge data as a printable HTML document."""
    return BADGE_TEMPLATE.format(
        company=html.escape(str(args["company"])),
        name=html.escape(str(args["name"])),
        type=html.escape(str(args["type"])),
    )


def write_badge(path: Path, markup: str) -> None:
    """Write badge markup, creating the output directory when needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(markup, encoding="utf-8")


@worker(queue="badges", max_attempts=5)
class GenerateBadge:
    """Render a badge requested through the shared Oban jobs table."""

    async def process(self, job: Job) -> None:
        path = BADGES_DIR / f"{job.args['id']}.html"
        await asyncio.to_thread(write_badge, path, render_badge(job.args))
