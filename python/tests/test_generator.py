from badge_forge.generator import render_badge, write_badge


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
