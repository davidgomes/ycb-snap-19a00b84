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

  describe "get_loaded_resource/3" do
    test "returns the assigned resource when it is a struct of the model" do
      assert get_loaded_resource(%{post: %Post{id: 1}}, :post, model: Post) == %Post{id: 1}
    end

    test "returns nil when the resource is not assigned or is not a struct of the model" do
      assert get_loaded_resource(%{}, :post, model: Post) == nil
      assert get_loaded_resource(%{post: nil}, :post, model: Post) == nil
      assert get_loaded_resource(%{post: %User{id: 1}}, :post, model: Post) == nil
      assert get_loaded_resource(%{post: [%Post{id: 1}]}, :post, model: Post) == nil
      assert get_loaded_resource(%{post: %{id: 1}}, :post, model: Post) == nil
    end
  end

  describe "get_resource_or_model/3" do
    test "returns the loaded resource" do
      assert get_resource_or_model(%{post: %Post{id: 1}}, :post, model: Post) == %Post{id: 1}

      assert get_resource_or_model(%{post: %Post{id: 1}}, :post, model: Post, required: true) ==
               %Post{id: 1}
    end

    test "returns the model when the resource is not loaded" do
      assert get_resource_or_model(%{}, :post, model: Post) == Post
      assert get_resource_or_model(%{post: %User{}}, :post, model: Post) == Post
    end

    test "returns nil when the resource is required and not loaded" do
      assert get_resource_or_model(%{}, :post, model: Post, required: true) == nil
      assert get_resource_or_model(%{post: %User{}}, :post, model: Post, required: true) == nil
    end
  end

  describe "load_resource_from_repo/2" do
    setup do
      Application.put_env(:canary, :repo, Repo)
    end

    test "loads the resource by the id from params or conn" do
      assert load_resource_from_repo(%{"id" => "1"}, model: Post) == %Post{id: 1}

      assert load_resource_from_repo(%Plug.Conn{params: %{"id" => "2"}}, model: Post) ==
               %Post{id: 2, user_id: 2}

      opts = [model: Post, id_name: "slug", id_field: "slug"]
      assert load_resource_from_repo(%{"slug" => "slug1"}, opts) == %Post{id: 1, slug: "slug1"}

      assert load_resource_from_repo(%{"id" => "3"}, model: Post) == nil
    end

    test "preloads associations" do
      assert load_resource_from_repo(%{"id" => "2"}, model: Post, preload: :user) ==
               %Post{id: 2, user_id: 2, user: %User{id: 2}}
    end

    test "returns nil without querying the repo when the id is missing" do
      assert load_resource_from_repo(%{}, model: Post) == nil
      assert load_resource_from_repo(%{"id" => "1"}, model: Post, id_name: "post_id") == nil
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
