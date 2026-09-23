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
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts", "title", "votes:integer", "cost:decimal",
                                        "tags:array:text", "popular:boolean", "drafted_at:naive_datetime",
                                        "secret:uuid", "announcement_date:date", "alarm:time",
                                        "user_id:references:users"]

      assert_file "lib/phoenix_slime/blog/post.ex"
      assert_file "lib/phoenix_slime/blog/blog.ex"
      assert_file "test/phoenix_slime/blog/blog_test.exs"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file "lib/phoenix_slime_web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostController"
        assert file =~ "use PhoenixSlimeWeb, :controller"
        assert file =~ "Blog.get_post!"
      end

      assert_file "lib/phoenix_slime_web/views/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostView do"
        assert file =~ "use PhoenixSlimeWeb, :view"
      end

      assert_file "test/phoenix_slime_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostControllerTest"
      end

      assert_file "lib/phoenix_slime_web/templates/post/edit.html.slime", fn file ->
        assert file =~ "h2 Edit Post"
        assert file =~ "Map.put(assigns, :action, post_path(@conn, :update, @post))"
      end

      assert_file "lib/phoenix_slime_web/templates/post/form.html.slime", fn file ->
        assert file =~ "= form_for @changeset, @action, fn f ->"
        assert file =~ ~s(= text_input f, :title, class: "form-control")
        assert file =~ ~s(= number_input f, :votes, class: "form-control")
        assert file =~ ~s(= number_input f, :cost, step: "any", class: "form-control")
        assert file =~ ~s(= checkbox f, :popular, class: "checkbox")
        assert file =~ ~s(= datetime_select f, :drafted_at, class: "form-control")
        assert file =~ ~s(= date_select f, :announcement_date, class: "form-control")
        assert file =~ ~s(= time_select f, :alarm, class: "form-control")
        assert file =~ ~s(= text_input f, :secret, class: "form-control")
        assert file =~ ~s(= label f, :title, class: "control-label")
        assert file =~ ~s(= error_tag f, :title)

        refute file =~ ~s(= label f, :user_id)
        refute file =~ ~s(= number_input f, :user_id)
        refute file =~ ":tags"
      end

      assert_file "lib/phoenix_slime_web/templates/post/index.html.slime", fn file ->
        assert file =~ "h2 Listing Posts"
        assert file =~ "th Title"
        assert file =~ "= for post <- @posts do"
        assert file =~ "td= post.title"
        assert file =~ "post_path(@conn, :show, post)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/new.html.slime", fn file ->
        assert file =~ "h2 New Post"
        assert file =~ "Map.put(assigns, :action, post_path(@conn, :create))"
      end

      assert_file "lib/phoenix_slime_web/templates/post/show.html.slime", fn file ->
        assert file =~ "h2 Show Post"
        assert file =~ "strong Title:"
        assert file =~ "= @post.title"
      end

      refute_file "lib/phoenix_slime_web/templates/post/form.html.eex"

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/posts", PostController)
    end
  end

  test "generates html resource with web namespace" do
    in_tmp "phx generates namespaced html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts", "title:string", "--web", "Admin"]

      assert_file "lib/phoenix_slime_web/controllers/admin/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Admin.PostController"
      end

      assert_file "lib/phoenix_slime_web/views/admin/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Admin.PostView do"
      end

      assert_file "lib/phoenix_slime_web/templates/admin/post/index.html.slime", fn file ->
        assert file =~ "admin_post_path(@conn, :show, post)"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/posts", PostController)
    end
  end

  test "generates html resource without context or schema" do
    in_tmp "phx generates html resource without context", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts", "--no-context", "--no-schema", "title:string"]

      refute_file "lib/phoenix_slime/blog/blog.ex"
      refute_file "lib/phoenix_slime/blog/post.ex"
      assert [] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file "lib/phoenix_slime_web/controllers/post_controller.ex"
      assert_file "lib/phoenix_slime_web/templates/post/form.html.slime", fn file ->
        refute file =~ "--no-context"
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
        Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts"]

        assert_file "lib/phoenix_slime_web/templates/post/edit.html.slim"
        assert_file "lib/phoenix_slime_web/templates/post/form.html.slim"
        assert_file "lib/phoenix_slime_web/templates/post/index.html.slim"
        assert_file "lib/phoenix_slime_web/templates/post/new.html.slim"
        assert_file "lib/phoenix_slime_web/templates/post/show.html.slim"
      end
    end
  end

  test "invalid mix arguments" do
    assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["blog", "Post", "posts", "title:string"]
    end

    assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post"]
    end
  end
end
