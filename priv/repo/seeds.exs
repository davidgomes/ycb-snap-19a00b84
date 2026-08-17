# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BadgeForge.Repo.insert!(%BadgeForge.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Enqueue a sample badge render job. The job is executed by
# `BadgeForge.Workers.PythonBadgeRenderer`, which shells out to the Python
# script in `priv/python/render_badge.py`.
{:ok, _job} = BadgeForge.Badges.enqueue_render("build", "passing")
