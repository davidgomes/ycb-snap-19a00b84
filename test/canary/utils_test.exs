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

    test "accepts atom :id_name" do
      assert get_resource_id(%{"user_id" => "7"}, id_name: :user_id) == "7"
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

  describe "get_resource_name/1" do
    test "infers the name from the model" do
      assert get_resource_name(model: Post) == :post
      assert get_resource_name(model: Some.Project.BlogPost) == :blog_post
    end

    test "uses :as when provided" do
      assert get_resource_name(model: Post, as: :my_post) == :my_post
    end
  end

  describe "get_current_user/2" do
    test "fetches the subject from conn or socket assigns" do
      assert get_current_user(%Plug.Conn{assigns: %{current_user: %User{id: 1}}}, []) ==
               %User{id: 1}

      assert get_current_user(%Phoenix.LiveView.Socket{assigns: %{member: nil}}, current_user: :member) ==
               nil
    end

    test "raises when the subject key is not assigned" do
      assert_raise KeyError, ~r/^key :current_user not found/, fn ->
        get_current_user(%Phoenix.LiveView.Socket{assigns: %{}}, [])
      end
    end
  end

  describe "get_resource/3" do
    setup do
      Application.put_env(:canary, :repo, Repo)
    end

    test "returns the assigned resource of the model type" do
      conn = %Plug.Conn{assigns: %{post: %Post{id: 5}}}
      assert get_assigned_resource(conn, model: Post) == %Post{id: 5}
      assert get_resource(conn, %{"id" => "1"}, model: Post) == %Post{id: 5}
    end

    test "loads the resource when it's not assigned or of other type" do
      socket = %Phoenix.LiveView.Socket{assigns: %{post: %User{id: 1}}}
      assert get_assigned_resource(socket, model: Post) == nil
      assert get_resource(socket, %{"id" => "1"}, model: Post) == %Post{id: 1}
    end

    test "accepts atom and string :id_field" do
      params = %{"id" => "slug1"}
      assert repo_get_resource(params, model: Post, id_field: :slug) == %Post{id: 1, slug: "slug1"}
      assert repo_get_resource(params, model: Post, id_field: "slug") == %Post{id: 1, slug: "slug1"}
    end
  end

  test "required?/1 returns true if the resource is required" do
    assert required?(required: true) == true
    assert required?(required: false) == false
    assert required?([]) == false
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

    test "accepts :error_handler in opts" do
      Application.put_env(:canary, :error_handler, Canary.DefaultHandler)

      conn = apply_error_handler(%Plug.Conn{}, :not_found_handler, error_handler: CustomErrorHandler)
      assert conn.assigns[:ok_custom_not_found_handler] == true

      conn =
        apply_error_handler(%Plug.Conn{}, :not_found_handler,
          error_handler: Canary.DefaultHandler,
          not_found_handler: {CustomErrorHandler, :custom_handler}
        )

      assert conn.assigns[:ok_custom_handler] == true
    end
  end
end
