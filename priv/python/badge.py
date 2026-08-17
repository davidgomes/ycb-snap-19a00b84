#!/usr/bin/env python3
"""Python script invoked by BadgeForge.Workers.PythonWorker via Oban.

Reads a JSON payload from argv[1] and prints a JSON result to stdout.
"""
import json
import sys


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "missing payload"}))
        sys.exit(1)

    payload = json.loads(sys.argv[1])
    name = payload.get("name", "world")

    result = {"message": f"Hello, {name}, from Python!"}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
