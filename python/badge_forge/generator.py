"""Generates conference badges.

Jobs are enqueued from `BadgeForge.Badges` on the Elixir side, targeting the
`badge_forge.generator.GenerateBadge` worker below by its fully qualified
name. Both runtimes read and write the same `oban_jobs` table, so enqueueing
in Elixir and processing here in Python requires no additional glue.
"""

import logging

from oban import Job, worker

logger = logging.getLogger(__name__)


@worker(queue="badges", max_attempts=5)
class GenerateBadge:
    """Renders a badge for an attendee, speaker, sponsor, or organizer."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        company = job.args["company"]
        kind = job.args["type"]

        logger.info("Generating %s badge %s for %s (%s)", kind, badge_id, name, company)
