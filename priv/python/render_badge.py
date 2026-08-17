#!/usr/bin/env python3
"""Render a simple SVG badge.

Invoked by ``BadgeForge.Workers.PythonBadgeRenderer`` (an Oban worker) via
``System.cmd/3`` as ``render_badge.py <label> <value>``. Writes the
rendered SVG badge to stdout.
"""

import sys

TEMPLATE = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="20">'
    '<rect width="{label_width}" height="20" fill="#555"/>'
    '<rect x="{label_width}" width="{value_width}" height="20" fill="#4c1"/>'
    '<text x="{label_x}" y="14" fill="#fff" font-family="sans-serif" '
    'font-size="11" text-anchor="middle">{label}</text>'
    '<text x="{value_x}" y="14" fill="#fff" font-family="sans-serif" '
    'font-size="11" text-anchor="middle">{value}</text>'
    "</svg>"
)


def render(label: str, value: str) -> str:
    label_width = max(len(label) * 7 + 10, 20)
    value_width = max(len(value) * 7 + 10, 20)

    return TEMPLATE.format(
        width=label_width + value_width,
        label_width=label_width,
        value_width=value_width,
        label_x=label_width // 2,
        value_x=label_width + value_width // 2,
        label=label,
        value=value,
    )


def main() -> int:
    if len(sys.argv) != 3:
        sys.stderr.write("usage: render_badge.py <label> <value>\n")
        return 1

    _, label, value = sys.argv
    sys.stdout.write(render(label, value))
    return 0


if __name__ == "__main__":
    sys.exit(main())
