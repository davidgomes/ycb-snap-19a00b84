import Config

if config_env() == :test do
  config :ecto, json_library: Jason
  config :postgrex, json_library: Jason
  config :oban, json_library: Jason

  import_config "test.exs"
end
