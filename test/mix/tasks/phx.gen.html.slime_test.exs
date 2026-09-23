Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.Html.SlimeTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "generates html resource with context" do
    in_tmp "phx generates html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Accounts User users name age:integer height:decimal
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

      assert_file "test/phoenix_slime_web/controllers/user_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.UserControllerTest"
        assert file =~ "use PhoenixSlimeWeb.ConnCase"
      end

      assert_file "lib/phoenix_slime_web/templates/user/edit.html.slime", fn file ->
        assert file =~ "h2 Edit User"
        assert file =~ "Map.put(assigns, :action, user_path(@conn, :update, @user))"
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

        refute file =~ ~s(= label f, :address_id)
        refute file =~ ~s(= number_input f, :address_id)
        refute file =~ ":nicks"
      end

      assert_file "lib/phoenix_slime_web/templates/user/index.html.slime", fn file ->
        assert file =~ "h2 Listing Users"
        assert file =~ "th Name"
        assert file =~ "= for user <- @users do"
        assert file =~ "td= user.name"
        assert file =~ ~s|span= link "Show", to: user_path(@conn, :show, user)|
      end

      assert_file "lib/phoenix_slime_web/templates/user/new.html.slime", fn file ->
        assert file =~ "h2 New User"
        assert file =~ "Map.put(assigns, :action, user_path(@conn, :create))"
      end

      assert_file "lib/phoenix_slime_web/templates/user/show.html.slime", fn file ->
        assert file =~ "h2 Show User"
        assert file =~ "strong Name:"
        assert file =~ "= @user.name"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/users", UserController)
    end
  end

  test "generates html resource with web namespace" do
    in_tmp "phx generates namespaced html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Accounts SuperUser super_users name:string --web Admin)

      assert_file "lib/phoenix_slime_web/controllers/admin/super_user_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Admin.SuperUserController"
      end

      assert_file "lib/phoenix_slime_web/views/admin/super_user_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Admin.SuperUserView do"
      end

      assert_file "lib/phoenix_slime_web/templates/admin/super_user/edit.html.slime", fn file ->
        assert file =~ "h2 Edit Super user"
        assert file =~ "admin_super_user_path(@conn, :update, @super_user)"
      end

      assert_file "lib/phoenix_slime_web/templates/admin/super_user/index.html.slime", fn file ->
        assert file =~ "h2 Listing Super users"
        assert file =~ "= for super_user <- @super_users do"
      end

      assert_file "lib/phoenix_slime_web/templates/admin/super_user/form.html.slime"
      assert_file "lib/phoenix_slime_web/templates/admin/super_user/new.html.slime"
      assert_file "lib/phoenix_slime_web/templates/admin/super_user/show.html.slime"

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/super_users", SuperUserController)
    end
  end

  test "generates html resource without context or schema" do
    in_tmp "phx generates html resource without context", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Accounts User users name:string --no-context --no-schema)

      refute_file "lib/phoenix_slime/accounts/accounts.ex"
      refute_file "lib/phoenix_slime/accounts/user.ex"
      assert [] = Path.wildcard("priv/repo/migrations/*_create_users.exs")

      assert_file "lib/phoenix_slime_web/controllers/user_controller.ex"
      assert_file "lib/phoenix_slime_web/templates/user/form.html.slime", fn file ->
        assert file =~ ~s(= text_input f, :name, class: "form-control")
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
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Accounts User users)

        assert File.exists? "lib/phoenix_slime_web/templates/user/edit.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/user/form.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/user/index.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/user/new.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/user/show.html.slim"
      end
    end
  end

  test "invalid mix arguments" do
    in_tmp "phx invalid mix arguments", fn ->
      assert_raise Mix.Error, ~r/Expected the context, "accounts", to be a valid module name/, fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(accounts User users name:string)
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(User User users)
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Accounts User)
      end
    end
  end
end
