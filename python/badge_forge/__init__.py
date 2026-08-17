"""Python Oban worker package for BadgeForge.

Jobs enqueued from the Elixir application (see `BadgeForge.Badges`) land in
the `badges` queue and are processed by the workers defined in this package.
Oban for Python and Oban for Elixir read and write the same `oban_jobs`
table, so no message broker or RPC layer is needed to bridge the two
runtimes.
"""
