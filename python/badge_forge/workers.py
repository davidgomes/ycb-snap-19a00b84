import asyncio
import logging

from oban import Job, worker

from badge_forge.badges import generate_badge

logger = logging.getLogger(__name__)


@worker(queue="badges")
class GenerateBadge:
    """Generate a conference badge PDF."""

    async def process(self, job: Job) -> None:
        badge_id = job.args["id"]
        name = job.args["name"]
        badge_type = job.args["type"]
        company = job.args.get("company")

        logger.info(f"Generating badge for {name} ({badge_type}): {badge_id}")

        badge_path = await asyncio.to_thread(
            generate_badge,
            badge_id=badge_id,
            name=name,
            badge_type=badge_type,
            company=company,
        )

        logger.info(f"Badge generated: {badge_path}")
