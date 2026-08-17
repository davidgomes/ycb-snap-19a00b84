defmodule ObanDoctor.ConfigFileTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.ConfigFile
  alias ObanDoctor.Config

  describe "config_path/1" do
    test "returns path to .oban_doctor.exs in given directory" do
      assert ConfigFile.config_path("/my/project") == "/my/project/.oban_doctor.exs"
    end
  end

  describe "load/1" do
    test "returns default config when no config file exists" do
      tmp_dir = create_temp_project()

      assert {:ok, config} = ConfigFile.load(tmp_dir)
      assert config == Config.new()
    end

    test "loads config from .oban_doctor.exs file" do
      tmp_dir = create_temp_project()

      config_content = """
      [
        checks: [
          missing_queue: [enabled: false]
        ],
        excluded_workers: [MyApp.LegacyWorker]
      ]
      """

      write_config_file(tmp_dir, config_content)

      assert {:ok, config} = ConfigFile.load(tmp_dir)
      assert config.excluded_workers == [MyApp.LegacyWorker]
      assert config.checks[:missing_queue][:enabled] == false
    end

    test "returns error for syntax errors" do
      tmp_dir = create_temp_project()

      config_content = """
      [
        checks: [
          missing_queue: [enabled: false
        ]
      ]
      """

      write_config_file(tmp_dir, config_content)

      assert {:error, message} = ConfigFile.load(tmp_dir)
      assert message =~ "syntax error"
    end

    test "returns error when config doesn't return keyword list" do
      tmp_dir = create_temp_project()

      config_content = """
      "not a keyword list"
      """

      write_config_file(tmp_dir, config_content)

      assert {:error, message} = ConfigFile.load(tmp_dir)
      assert message =~ "must return a keyword list"
    end
  end

  describe "load!/1" do
    test "returns config when valid" do
      tmp_dir = create_temp_project()

      config_content = """
      [
        excluded_workers: [MyApp.TestWorker]
      ]
      """

      write_config_file(tmp_dir, config_content)

      config = ConfigFile.load!(tmp_dir)
      assert config.excluded_workers == [MyApp.TestWorker]
    end

    test "raises on error" do
      tmp_dir = create_temp_project()

      config_content = """
      "invalid"
      """

      write_config_file(tmp_dir, config_content)

      assert_raise RuntimeError, ~r/Failed to load config/, fn ->
        ConfigFile.load!(tmp_dir)
      end
    end
  end

  describe "default_config_content/1" do
    test "generates config with no checks" do
      content = ConfigFile.default_config_content([])

      assert content =~ "# ObanDoctor Configuration"
      assert content =~ "checks: ["
      assert content =~ "# No checks configured yet"
      assert content =~ "excluded_workers: ["
      assert content =~ "excluded_files: ["
    end

    test "generates config with checks" do
      defmodule FakeCheck do
        def id, do: :fake_check
      end

      content = ConfigFile.default_config_content([FakeCheck])

      assert content =~ "fake_check: [enabled: true]"
    end
  end

  # Helper functions

  defp create_temp_project do
    tmp_dir = Path.join(System.tmp_dir!(), "oban_doctor_config_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    tmp_dir
  end

  defp write_config_file(root, content) do
    File.write!(Path.join(root, ".oban_doctor.exs"), content)
  end
end
