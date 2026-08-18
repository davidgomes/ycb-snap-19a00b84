import asyncio

from oban import Job

import badge_forge.generator as generator
from badge_forge.generator import GenerateBadge, render_badge, write_badge


def test_render_badge_escapes_job_arguments():
    markup = render_badge(
        {
            "company": "Analytical Engines & Co.",
            "name": "Ada <Lovelace>",
            "type": "speaker",
        }
    )

    assert "Ada &lt;Lovelace&gt;" in markup
    assert "Analytical Engines &amp; Co." in markup
    assert 'class="badge speaker"' in markup


def test_write_badge_creates_the_output_directory(tmp_path):
    path = tmp_path / "badges" / "badge.html"

    write_badge(path, "<html>badge</html>")

    assert path.read_text(encoding="utf-8") == "<html>badge</html>"


def test_worker_writes_a_badge_enqueued_by_elixir(tmp_path, monkeypatch):
    monkeypatch.setattr(generator, "BADGES_DIR", tmp_path)
    job = Job(
        "badge_forge.generator.GenerateBadge",
        args={
            "id": "badge-123",
            "company": "Analytical Engines",
            "name": "Ada Lovelace",
            "type": "speaker",
        },
        queue="badges",
    )

    asyncio.run(GenerateBadge().process(job))

    markup = (tmp_path / "badge-123.html").read_text(encoding="utf-8")
    assert "Ada Lovelace" in markup
