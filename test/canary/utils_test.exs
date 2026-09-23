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
    assert required?([]) == false
  end

  test "persisted?/1 returns true if the resource is persisted or required" do
    assert persisted?(persisted: true) == true
    assert persisted?(required: true) == true
    assert persisted?(persisted: false, required: false) == false
    assert persisted?([]) == false
  end

  test "non_id_actions/1 returns the default and the :non_id_actions actions" do
    assert non_id_actions([]) == [:index, :new, :create]
    assert non_id_actions(non_id_actions: [:search]) == [:index, :new, :create, :search]
  end

  test "get_resource_name/1 returns the :as option or the underscored model name" do
    assert get_resource_name(model: Post) == :post
    assert get_resource_name(model: Some.Project.BlogPost) == :blog_post
    assert get_resource_name(model: Post, as: :my_post) == :my_post
  end

  describe "get_current_user/2" do
    test "returns the current user from the conn or socket assigns" do
      conn = %Plug.Conn{assigns: %{current_user: %User{id: 1}, admin: %User{id: 2}}}
      assert get_current_user(conn, []) == %User{id: 1}
      assert get_current_user(conn, current_user: :admin) == %User{id: 2}

      socket = %Phoenix.LiveView.Socket{assigns: %{current_user: nil}}
      assert get_current_user(socket, []) == nil
    end

    test "raises when the current user is not assigned" do
      assert_raise KeyError, ~r/key :admin not found/, fn ->
        get_current_user(%Plug.Conn{assigns: %{current_user: %User{}}}, current_user: :admin)
      end
    end
  end

  describe "fetch_resource/3" do
    test "returns the assigned resource of the model" do
      socket = %Phoenix.LiveView.Socket{assigns: %{post: %Post{id: 2}}}

      assert get_assigned_resource(socket, model: Post) == %Post{id: 2}
      assert fetch_resource(socket, %{"id" => "1"}, model: Post) == %Post{id: 2}
    end

    test "loads the resource from the repo when a resource of the model is not assigned" do
      Application.put_env(:canary, :repo, Repo)
      conn = %Plug.Conn{assigns: %{post: %User{id: 2}}}

      assert get_assigned_resource(conn, model: Post) == nil
      assert fetch_resource(conn, %{"id" => "1"}, model: Post) == %Post{id: 1}
      assert fetch_resource(conn, %{"id" => "13"}, model: Post) == nil
      assert fetch_resource(conn, %{}, model: Post) == nil
    end
  end

  describe "authorized?/4" do
    setup do
      Application.put_env(:canary, :repo, Repo)
      :ok
    end

    test "authorizes non-id actions against the model" do
      conn = %Plug.Conn{assigns: %{current_user: %User{id: 1}, post: %Post{id: 2, user_id: 2}}}

      assert authorized?(conn, :new, %{}, model: Post) == true
      assert authorized?(conn, :other_action, %{}, model: Post) == false
      assert authorized?(conn, :other_action, %{}, model: Post, non_id_actions: [:other_action])
    end

    test "authorizes other actions against the loaded resource" do
      socket = %Phoenix.LiveView.Socket{assigns: %{current_user: %User{id: 1}}}

      assert authorized?(socket, :show, %{"id" => "1"}, model: Post) == true
      assert authorized?(socket, :show, %{"id" => "2"}, model: Post) == false
      assert authorized?(socket, :show, %{"id" => "13"}, model: Post) == false
      assert authorized?(socket, :new, %{"id" => "2"}, model: Post, persisted: true) == false
    end
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
