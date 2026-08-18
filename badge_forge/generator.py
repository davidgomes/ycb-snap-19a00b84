from pathlib import Path
from oban import Job, Oban, worker
from weasyprint import HTML

BADGES_DIR = Path("tmp/badges")
BADGES_DIR.mkdir(parents=True, exist_ok=True)


def render_badge_html(name: str, company: str, role: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page {{
            size: 4in 6in;
            margin: 0;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            padding: 20px;
            box-sizing: border-box;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
        }}
        .card {{
            background: white;
            color: #333;
            border-radius: 12px;
            padding: 30px 20px;
            width: 90%;
            box-shadow: 0 10px 25px rgba(0,0,0,0.2);
        }}
        .name {{
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 8px;
        }}
        .company {{
            font-size: 16px;
            color: #666;
            margin-bottom: 20px;
        }}
        .role {{
            display: inline-block;
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: bold;
            text-transform: uppercase;
            background-color: #4f46e5;
            color: white;
        }}
    </style>
</head>
<body>
    <div class="card">
        <div class="name">{name}</div>
        <div class="company">{company}</div>
        <div class="role">{role}</div>
    </div>
</body>
</html>
"""


@worker(max_attempts=5, queue="badges")
class GenerateBadge:
    async def process(self, job: Job) -> None:
        badge_id = job.args.get("id") or job.args.get("badge_id")
        name = job.args["name"]
        company = job.args.get("company", "")
        role = job.args.get("type", "")

        BADGES_DIR.mkdir(parents=True, exist_ok=True)
        html = render_badge_html(name, company, role)
        path = BADGES_DIR / f"{badge_id}.pdf"
        HTML(string=html).write_pdf(str(path))

        # Enqueue a confirmation job back to Elixir
        confirmation = Job(
            args={"id": badge_id, "name": name, "path": str(path)},
            queue="printing",
            worker="BadgeForge.PrintCenter",
        )
        await Oban.get_instance().enqueue(confirmation)

