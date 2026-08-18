port = 4000

{:ok, _} = Bandit.start_link(plug: Ocelot.Router, port: port)

IO.puts("Ocelot dashboard running at http://localhost:#{port}")

Process.sleep(:infinity)
