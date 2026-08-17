import logging

from oban import Job, worker

logger = logging.getLogger(__name__)


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF for an attendee.

    Jobs for this worker are enqueued from Elixir via
    `BadgeForge.generate_badge/2` and processed here.
    """

    async def process(self, job: Job) -> None:
        attendee_id = job.args["attendee_id"]
        name = job.args["name"]

        logger.info("Generating badge for %s (%s)", name, attendee_id)
