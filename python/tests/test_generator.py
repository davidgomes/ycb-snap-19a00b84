import pytest

from oban import Oban
from oban.testing import process_job

from badge_forge import generator
from badge_forge.generator import GenerateBadge


class FakeOban:
    def __init__(self):
        self.jobs = []

    async def enqueue(self, job, conn=None):
        self.jobs.append(job)

        return job


@pytest.fixture
def instance(monkeypatch):
    fake = FakeOban()

    monkeypatch.setattr(Oban, "get_instance", classmethod(lambda cls, name="Oban": fake))

    return fake


@pytest.fixture(autouse=True)
def badges_dir(tmp_path, monkeypatch):
    monkeypatch.setattr(generator, "BADGES_DIR", tmp_path)

    return tmp_path


def test_generating_a_badge_from_elixir_args(badges_dir, instance):
    args = {
        "id": "aa2e6c0f",
        "name": "Ada Lovelace",
        "company": "Analytical Engines",
        "type": "speaker",
    }

    process_job(GenerateBadge.new(args))

    path = badges_dir / "ada-lovelace-aa2e6c0f.html"

    assert path.exists()
    assert "Ada Lovelace" in path.read_text()
    assert "Analytical Engines" in path.read_text()


def test_enqueueing_a_printing_job_back_to_elixir(badges_dir, instance):
    args = {"id": "aa2e6c0f", "name": "Ada Lovelace"}

    process_job(GenerateBadge.new(args))

    assert len(instance.jobs) == 1

    job = instance.jobs[0]

    assert job.worker == "BadgeForge.PrintCenter"
    assert job.queue == "printing"
    assert job.args["path"].endswith("ada-lovelace-aa2e6c0f.html")


def test_worker_name_matches_the_name_used_from_elixir():
    assert GenerateBadge.new({"id": 1, "name": "x"}).worker == (
        "badge_forge.generator.GenerateBadge"
    )
    assert GenerateBadge.new({"id": 1, "name": "x"}).queue == "badges"


def test_escaping_attendee_details():
    markup = generator.render_badge({"id": 1, "name": "<script>", "company": "&"})

    assert "<script>" not in markup
    assert "&lt;script&gt;" in markup
