import logging

from oban import Job, worker

logger = logging.getLogger(__name__)


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        badge_type = job.args["type"]

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        # TODO: Generate actual PDF with weasyprint
        badge_path = f"/badges/{badge_id}.pdf"

        logger.info(f"Badge generated: {badge_path}")
