compose:
	docker-compose -f docker-compose-test.yml up -d

db_setup:
	MIX_ENV=test mix do ecto.create, ecto.migrate

db_setup_myxql:
	MIX_ENV=test_myxql mix do ecto.create, ecto.migrate

test: compose db_setup
	mix test

test_myxql: compose db_setup_myxql
	MIX_ENV=test_myxql mix test
