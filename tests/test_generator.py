import asyncio
import pytest
from pathlib import Path
from oban import Job, Oban
from badge_forge.generator import GenerateBadge, render_badge_html, BADGES_DIR


def test_render_badge_html():
    html = render_badge_html("Ada Lovelace", "Analytical Engines", "speaker")
    assert "Ada Lovelace" in html
    assert "Analytical Engines" in html
    assert "speaker" in html


@pytest.mark.asyncio
async def test_generate_badge_process(tmp_path, monkeypatch):
    test_badges_dir = tmp_path / "badges"
    monkeypatch.setattr("badge_forge.generator.BADGES_DIR", test_badges_dir)

    enqueued_jobs = []

    class MockOban:
        async def enqueue(self, job):
            enqueued_jobs.append(job)
            return job

    monkeypatch.setattr(Oban, "get_instance", lambda: MockOban())

    job = Job(
        id=1,
        args={
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Alan Turing",
            "company": "Bletchley Park",
            "type": "organizer",
        },
        queue="badges",
        worker="badge_forge.generator.GenerateBadge",
    )

    worker_instance = GenerateBadge()
    await worker_instance.process(job)

    pdf_path = test_badges_dir / "123e4567-e89b-12d3-a456-426614174000.pdf"
    assert pdf_path.exists()
    assert pdf_path.stat().st_size > 0

    assert len(enqueued_jobs) == 1
    confirmation_job = enqueued_jobs[0]
    assert confirmation_job.queue == "printing"
    assert confirmation_job.worker == "BadgeForge.PrintCenter"
    assert confirmation_job.args["id"] == "123e4567-e89b-12d3-a456-426614174000"
    assert confirmation_job.args["name"] == "Alan Turing"
    assert confirmation_job.args["path"] == str(pdf_path)
