Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.Html.SlimeTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "generates html resource" do
    in_tmp "phx generates html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Accounts", "User", "users", "name", "age:integer",
                                        "height:decimal", "nicks:array:text", "famous:boolean",
                                        "born_at:naive_datetime", "secret:uuid",
                                        "first_login:date", "alarm:time"]

      assert_file "lib/phoenix_slime/accounts/user.ex"
      assert_file "lib/phoenix_slime/accounts/accounts.ex"
      assert_file "test/phoenix_slime/accounts/accounts_test.exs"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_users.exs")

      assert_file "lib/phoenix_slime_web/controllers/user_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.UserController"
        assert file =~ "use PhoenixSlimeWeb, :controller"
      end

      assert_file "lib/phoenix_slime_web/views/user_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.UserView do"
        assert file =~ "use PhoenixSlimeWeb, :view"
      end

      assert_file "test/phoenix_slime_web/controllers/user_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.UserControllerTest"
      end

      assert_file "lib/phoenix_slime_web/templates/user/edit.html.slime", fn file ->
        assert file =~ "h2 Edit User"
        assert file =~ "action, user_path(@conn, :update, @user)"
      end

      assert_file "lib/phoenix_slime_web/templates/user/form.html.slime", fn file ->
        assert file =~ ~s(= text_input f, :name, class: "form-control")
        assert file =~ ~s(= number_input f, :age, class: "form-control")
        assert file =~ ~s(= number_input f, :height, step: "any", class: "form-control")
        assert file =~ ~s(= checkbox f, :famous, class: "checkbox")
        assert file =~ ~s(= datetime_select f, :born_at, class: "form-control")
        assert file =~ ~s(= text_input f, :secret, class: "form-control")
        assert file =~ ~s(= date_select f, :first_login, class: "form-control")
        assert file =~ ~s(= time_select f, :alarm, class: "form-control")
        assert file =~ ~s(= label f, :name, class: "control-label")
        assert file =~ ~s(= error_tag f, :name)
        refute file =~ ":nicks"
      end

      assert_file "lib/phoenix_slime_web/templates/user/index.html.slime", fn file ->
        assert file =~ "h2 Listing Users"
        assert file =~ "th Name"
        assert file =~ "= for user <- @users do"
        assert file =~ "td= user.name"
      end

      assert_file "lib/phoenix_slime_web/templates/user/new.html.slime", fn file ->
        assert file =~ "h2 New User"
        assert file =~ "action, user_path(@conn, :create)"
      end

      assert_file "lib/phoenix_slime_web/templates/user/show.html.slime", fn file ->
        assert file =~ "h2 Show User"
        assert file =~ "strong Name:"
        assert file =~ "= @user.name"
      end

      refute_file "lib/phoenix_slime_web/templates/user/index.html.eex"

      assert_received {:mix_shell, :info, ["\nAdd the resource to your browser scope in lib/phoenix_slime_web/router.ex:" <> _ = message]}
      assert message =~ ~s(resources "/users", UserController)
    end
  end

  test "generates html resource with --web namespace" do
    in_tmp "phx generates html resource with web namespace", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts", "title:string", "--web", "Admin"]

      assert_file "lib/phoenix_slime_web/controllers/admin/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Admin.PostController"
      end

      assert_file "lib/phoenix_slime_web/templates/admin/post/index.html.slime", fn file ->
        assert file =~ "admin_post_path(@conn, :new)"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource to your Admin :browser scope" <> _ = message]}
      assert message =~ ~s(resources "/posts", PostController)
    end
  end

  test "generates html resource without context or schema" do
    in_tmp "phx generates html resource without context", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts", "title:string", "--no-context", "--no-schema"]

      refute_file "lib/phoenix_slime/blog/blog.ex"
      refute_file "lib/phoenix_slime/blog/post.ex"
      assert [] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file "lib/phoenix_slime_web/templates/post/form.html.slime"
    end
  end

  describe "when :use_slim_extension env is set to true" do
    setup do
      Application.put_env(:phoenix_slime, :use_slim_extension, true)
      on_exit fn ->
        Application.delete_env(:phoenix_slime, :use_slim_extension)
      end
      :ok
    end

    test "generates files with .slim extension" do
      in_tmp "phx generates .slim", fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ["Accounts", "User", "users"]

        for template <- ~w(edit form index new show) do
          assert File.exists? "lib/phoenix_slime_web/templates/user/#{template}.html.slim"
        end
      end
    end
  end

  test "raises with invalid arguments" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["User", "users"]
    end
  end
end
