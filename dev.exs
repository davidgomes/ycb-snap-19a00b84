{:ok, _pid} = Bandit.start_link(plug: Ocelot.Router, port: 4000)

IO.puts("Ocelot dashboard running at http://localhost:4000")
