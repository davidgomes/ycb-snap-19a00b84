Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.Html.SlimeTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear
    :ok
  end

  test "generates html resource" do
    in_tmp "phx generates html resource", fn ->
      Gen.Html.Slime.run ~w(Accounts User users name age:integer height:decimal
                            nicks:array:text famous:boolean born_at:naive_datetime
                            secret:uuid first_login:date alarm:time
                            address_id:references:addresses)

      assert_file "lib/phoenix_slime/accounts/user.ex"
      assert_file "lib/phoenix_slime/accounts/accounts.ex"
      assert_file "test/phoenix_slime/accounts/accounts_test.exs"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_users.exs")

      assert_file "lib/phoenix_slime_web/controllers/user_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.UserController"
        assert file =~ "use PhoenixSlimeWeb, :controller"
        assert file =~ "Accounts.get_user!"
      end

      assert_file "lib/phoenix_slime_web/views/user_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.UserView do"
        assert file =~ "use PhoenixSlimeWeb, :view"
      end

      assert_file "lib/phoenix_slime_web/templates/user/edit.html.slime", fn file ->
        assert file =~ "h2 Edit User"
        assert file =~ "Map.merge(assigns, %{action: user_path(@conn, :update, @user)})"
      end

      assert_file "lib/phoenix_slime_web/templates/user/form.html.slime", fn file ->
        assert file =~ ~s(= text_input f, :name, class: "form-control")
        assert file =~ ~s(= number_input f, :age, class: "form-control")
        assert file =~ ~s(= number_input f, :height, step: "any", class: "form-control")
        assert file =~ ~s(= checkbox f, :famous, class: "form-control")
        assert file =~ ~s(= datetime_select f, :born_at, class: "form-control")
        assert file =~ ~s(= text_input f, :secret, class: "form-control")
        assert file =~ ~s(= date_select f, :first_login, class: "form-control")
        assert file =~ ~s(= time_select f, :alarm, class: "form-control")
        assert file =~ ~s(= label f, :name, class: "control-label")
        assert file =~ ~s(= label f, :age, class: "control-label")
        assert file =~ ~s(= label f, :height, class: "control-label")
        assert file =~ ~s(= label f, :famous, class: "control-label")
        assert file =~ ~s(= label f, :born_at, class: "control-label")
        assert file =~ ~s(= label f, :secret, class: "control-label")
        assert file =~ ~s(= error_tag f, :name)

        refute file =~ ~s(= label f, :address_id)
        refute file =~ ~s(= number_input f, :address_id)
        refute file =~ ":nicks"
      end

      assert_file "lib/phoenix_slime_web/templates/user/index.html.slime", fn file ->
        assert file =~ "h2 Listing Users"
        assert file =~ "th Name"
        assert file =~ "= for user <- @users do"
        assert file =~ "td= user.name"
        assert file =~ "user_path(@conn, :show, user)"
      end

      assert_file "lib/phoenix_slime_web/templates/user/new.html.slime", fn file ->
        assert file =~ "h2 New User"
        assert file =~ "Map.merge(assigns, %{action: user_path(@conn, :create)})"
      end

      assert_file "lib/phoenix_slime_web/templates/user/show.html.slime", fn file ->
        assert file =~ "h2 Show User"
        assert file =~ "strong Name:"
        assert file =~ "= @user.name"
      end

      refute_file "lib/phoenix_slime_web/templates/user/form.html.eex"

      assert_file "test/phoenix_slime_web/controllers/user_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.UserControllerTest"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/users", UserController)
    end
  end

  test "with --web namespace generates namespaced web modules and directories" do
    in_tmp "phx generates namespaced html resource", fn ->
      Gen.Html.Slime.run ~w(Blog Post posts title:string --web Blog)

      assert_file "lib/phoenix_slime_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostController"
      end

      assert_file "lib/phoenix_slime_web/views/blog/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostView"
      end

      assert_file "test/phoenix_slime_web/controllers/blog/post_controller_test.exs"

      assert_file "lib/phoenix_slime_web/templates/blog/post/form.html.slime"

      for template <- ~w(edit index new show) do
        assert_file "lib/phoenix_slime_web/templates/blog/post/#{template}.html.slime", fn file ->
          assert file =~ " blog_post_path(@conn"
        end
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(scope "/blog", PhoenixSlimeWeb.Blog, as: :blog do)
      assert message =~ ~s(resources "/posts", PostController)
    end
  end

  test "with --no-context skips context and schema file generation" do
    in_tmp "phx generates html resource without context", fn ->
      Gen.Html.Slime.run ~w(Blog Comment comments title:string --no-context)

      refute_file "lib/phoenix_slime/blog/blog.ex"
      refute_file "lib/phoenix_slime/blog/comment.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "lib/phoenix_slime_web/controllers/comment_controller.ex"
      assert_file "lib/phoenix_slime_web/views/comment_view.ex"
      assert_file "lib/phoenix_slime_web/templates/comment/form.html.slime"
    end
  end

  test "with --no-schema skips schema file generation" do
    in_tmp "phx generates html resource without schema", fn ->
      Gen.Html.Slime.run ~w(Blog Comment comments title:string --no-schema)

      assert_file "lib/phoenix_slime/blog/blog.ex"
      refute_file "lib/phoenix_slime/blog/comment.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "lib/phoenix_slime_web/templates/comment/form.html.slime", fn file ->
        refute file =~ ~s(--no-schema)
      end
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
        Gen.Html.Slime.run ~w(Accounts User users)

        assert_file "lib/phoenix_slime_web/templates/user/edit.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/form.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/index.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/new.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/show.html.slim"
      end
    end
  end

  test "invalid mix arguments" do
    assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
      Gen.Html.Slime.run ~w(blog Post posts title:string)
    end

    assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
      Gen.Html.Slime.run ~w(Blog Blog blogs)
    end

    assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
      Gen.Html.Slime.run ~w(Blog Post)
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Gen.Html.Slime.run ~w(Blog Post title:string content:string)
    end
  end

  test "plural can't have uppercased characters or camelized format" do
    assert_raise Mix.Error, fn ->
      Gen.Html.Slime.run ~w(Blog User Users foo:string)
    end

    assert_raise Mix.Error, fn ->
      Gen.Html.Slime.run ~w(Admin User AdminUsers foo:string)
    end
  end
end
