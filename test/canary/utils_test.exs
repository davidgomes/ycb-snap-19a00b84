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

  describe "get_resource_name/2" do
    test "infers the resource name from the model" do
      assert get_resource_name(:show, model: MyApp.BlogPost) == :blog_post
      assert get_resource_name(:index, model: MyApp.BlogPost) == :blog_posts
      assert get_resource_name(:index, model: MyApp.BlogPost, required: true) == :blog_post
    end

    test "uses the :as option" do
      assert get_resource_name(:index, model: MyApp.BlogPost, as: :posts_list) == :posts_list
    end
  end

  test "non_id_actions/1 returns the default and configured non-id actions" do
    assert non_id_actions([]) == [:index, :new, :create]
    assert non_id_actions(non_id_actions: [:search]) == [:index, :new, :create, :search]
  end

  describe "apply_handle_not_found?/3" do
    test "returns true when the required resource is missing" do
      assert apply_handle_not_found?(:show, %{}, model: Post)
      assert apply_handle_not_found?(:new, %{post: nil}, model: Post)
      assert apply_handle_not_found?(:show, %{post: nil}, model: Post, required: false)
    end

    test "returns false when the resource is loaded or not required" do
      refute apply_handle_not_found?(:show, %{post: %Post{id: 1}}, model: Post)
      refute apply_handle_not_found?(:new, %{post: nil}, model: Post, required: false)
    end
  end

  test "validate_opts/1 warns about deprecated options" do
    assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
             assert validate_opts(persisted: true) == [persisted: true]
           end) =~ "The `:persisted` option is deprecated"

    assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
             validate_opts(non_id_actions: [:search])
           end) =~ "The `:non_id_actions` option is deprecated"

    assert ExUnit.CaptureIO.capture_io(:stderr, fn -> validate_opts(model: Post) end) == ""
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
