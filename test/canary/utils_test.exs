defmodule UtilsTest do
  import Canary.Utils

  use ExUnit.Case, async: true

  describe "get_resource_id/2" do
    test "returns the id from the params" do
      assert get_resource_id(%{"id" => "9"}, []) == "9"
      assert get_resource_id(%{"user_id" => "7"}, id_name: "user_id") == "7"
    end

    test "returns the id form conn.params" do
      conn = %Plug.Conn{params: %{"id" => "9"}}
      assert get_resource_id(conn, []) == "9"

      conn = %Plug.Conn{params: %{"custom_id" => "1"}}
      assert get_resource_id(conn, id_name: "custom_id") == "1"
    end

    test "returns nil if the id is not found" do
      assert get_resource_id(%{"other_id" => "9"}, id_name: "id") == nil

      conn = %Plug.Conn{params: %{"other_id" => "9"}}
      assert get_resource_id(conn, id_name: "id") == nil
    end
  end

  describe "action_valid?/2" do
    test "returns true if the action is valid" do
      assert action_valid?(:index, only: [:index, :show]) == true
      assert action_valid?(:show, except: :index) == true
    end

    test "returns false if the action is not valid" do
      assert action_valid?(:index, except: :index) == false
      assert action_valid?(:edit, only: [:index, :show]) == false
    end

    test "raise when both :only and :except are provided" do
      assert_raise ArgumentError, fn ->
        action_valid?(:index, only: [:index], except: :index)
      end
    end
  end

  test "required?/1 returns true if the resource is required" do
    assert required?(required: true) == true
    assert required?(required: false) == false
    assert required?([]) == true
  end

  test "get_resource_name/1 returns the resource name" do
    assert get_resource_name(model: Post) == :post
    assert get_resource_name(model: Some.Project.BlogPost) == :blog_post
    assert get_resource_name(model: Post, as: :my_post) == :my_post
  end

  test "get_current_user_name/1 returns the current user key" do
    assert get_current_user_name([]) == :current_user
    assert get_current_user_name(current_user: :my_user) == :my_user
  end

  test "repo_get_resource/2 loads the resource from the repo" do
    Application.put_env(:canary, :repo, Repo)

    assert repo_get_resource(%{"id" => "1"}, model: Post) == %Post{id: 1}
    assert repo_get_resource(%Plug.Conn{params: %{"post_id" => "1"}}, model: Post, id_name: "post_id") == %Post{id: 1}
    assert repo_get_resource(%{"id" => "slug1"}, model: Post, id_field: "slug") == %Post{id: 1, slug: "slug1"}
    assert repo_get_resource(%{"id" => "1"}, model: Post, preload: :user) == Repo.preload(%Post{id: 1}, :user)
    assert repo_get_resource(%{"id" => "13"}, model: Post) == nil
  end

  describe "apply_error_handler/3" do
    defmodule CustomErrorHandler do
      @behaviour Canary.ErrorHandler

      def not_found_handler(%Plug.Conn{} = conn) do
        %{conn | assigns: %{ok_custom_not_found_handler: true}}
      end
      def unauthorized_handler(%Plug.Conn{} = conn) do
        %{conn | assigns: %{ok_custom_unauthorized_handler: true}}
      end

      def custom_handler(%Plug.Conn{} = conn) do
        %{conn | assigns: %{ok_custom_handler: true}}
      end
    end

    test "raises if the error_handler is undefined" do
      assert_raise UndefinedFunctionError, ~r/function UnknownCustomErrorHandler.wrong_function\/1 is undefined/, fn ->
        apply_error_handler(%Plug.Conn{}, :unauthorized_handler, [
          unauthorized_handler: {UnknownCustomErrorHandler, :wrong_function}
        ])
      end

      assert_raise UndefinedFunctionError, ~r/function OtherErrorHandler.custom_function\/1 is undefined/, fn ->
        apply_error_handler(%Plug.Conn{}, :unauthorized_handler, [
          unauthorized_handler: {OtherErrorHandler, :custom_function}
        ])
      end
    end

    test "raises if the error_handler is not a module" do
      Application.put_env(:canary, :error_handler, 42)

      assert_raise ArgumentError, ~r/Invalid error handler, expected a module or a tuple with a module and a function/, fn ->
        apply_error_handler(%Plug.Conn{}, :not_found_handler, [])
      end
    end

    test "allows overriding the error handler" do
      Application.put_env(:canary, :error_handler, CustomErrorHandler)

      conn = apply_error_handler(%Plug.Conn{}, :not_found_handler, [])
      assert conn.assigns[:ok_custom_not_found_handler] == true

      conn = apply_error_handler(%Plug.Conn{}, :unauthorized_handler, [])
      assert conn.assigns[:ok_custom_unauthorized_handler] == true


      conn = apply_error_handler(%Plug.Conn{}, :unauthorized_handler, [unauthorized_handler: {Canary.DefaultHandler, :unauthorized_handler}])
      assert conn.assigns[:ok_custom_unauthorized_handler] == nil

      conn = apply_error_handler(%Plug.Conn{}, :not_found_handler, [
        not_found_handler: {CustomErrorHandler, :custom_handler}
        ])
      assert conn.assigns[:ok_custom_handler] == true
    end
  end
end

defmodule UtilsDeprecationTest do
  import Canary.Utils

  use ExUnit.Case, async: false

  test "warn_deprecated_opts/1 warns once about each deprecated option" do
    :persistent_term.erase({Canary.Utils, :deprecated, :persisted})
    :persistent_term.erase({Canary.Utils, :deprecated, :non_id_actions})

    assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
             warn_deprecated_opts(model: Post, persisted: true)
           end) =~ "The :persisted option is deprecated"

    assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
             warn_deprecated_opts(model: Post, persisted: true)
           end) == ""

    assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
             Canary.Plugs.authorize_resource(
               %Plug.Conn{
                 assigns: %{current_user: %User{id: 1}},
                 private: %{phoenix_action: :other_action}
               },
               model: Post,
               non_id_actions: [:other_action]
             )
           end) =~ "The :non_id_actions option is deprecated"

    assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
             warn_deprecated_opts(model: Post, required: true)
           end) == ""
  end
end
