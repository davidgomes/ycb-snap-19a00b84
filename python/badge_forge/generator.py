"""Badge generation, driven by jobs enqueued from Elixir."""

from __future__ import annotations

import os
import re
from html import escape
from pathlib import Path

from oban import Job, Oban, worker

REPO_ROOT = Path(__file__).resolve().parents[2]

BADGES_DIR = Path(os.getenv("BADGES_DIR", REPO_ROOT / "priv" / "badges"))

PRINT_WORKER = "BadgeForge.PrintCenter"

TEMPLATE = """<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>{name}</title>
  </head>
  <body>
    <main class="badge {type}">
      <h1>{name}</h1>
      <h2>{company}</h2>
      <p>{type}</p>
      <code>{id}</code>
    </main>
  </body>
</html>
"""


def render_badge(args: dict) -> str:
    """Render the badge markup for a single attendee."""
    return TEMPLATE.format(
        company=escape(str(args.get("company", ""))),
        id=escape(str(args["id"])),
        name=escape(str(args["name"])),
        type=escape(str(args.get("type", "attendee"))),
    )


def badge_path(args: dict) -> Path:
    slug = re.sub(r"[^a-z0-9]+", "-", str(args["name"]).lower()).strip("-")

    return BADGES_DIR / f"{slug}-{args['id']}.html"


@worker(queue="badges", max_attempts=5)
class GenerateBadge:
    """Generate a badge, then hand it back to Elixir for printing."""

    async def process(self, job: Job) -> None:
        path = badge_path(job.args)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(render_badge(job.args))

        print_job = Job(
            PRINT_WORKER,
            args={
                "id": job.args["id"],
                "name": job.args["name"],
                "path": str(path),
            },
            queue="printing",
        )

        await Oban.get_instance().enqueue(print_job)
