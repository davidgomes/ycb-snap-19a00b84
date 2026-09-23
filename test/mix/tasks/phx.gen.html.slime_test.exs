Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.Html.SlimeTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "invalid mix arguments" do
    in_tmp "phx invalid mix arguments", fn ->
      assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(blog Post posts title:string)
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post)
      end
    end
  end

  test "generates html resource" do
    in_tmp "phx generates html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post posts title votes:integer cost:decimal
                                          tags:array:text popular:boolean
                                          user_id:references:users)

      assert_file "lib/phoenix_slime/blog/post.ex"
      assert_file "lib/phoenix_slime/blog/blog.ex"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file "lib/phoenix_slime_web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostController"
        assert file =~ "Blog.list_posts"
      end

      assert_file "lib/phoenix_slime_web/views/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostView"
      end

      assert_file "test/phoenix_slime_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostControllerTest"
      end

      assert_file "lib/phoenix_slime_web/templates/post/edit.html.slime", fn file ->
        assert file =~ "h2 Edit Post"
        assert file =~ "action, post_path(@conn, :update, @post)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/form.html.slime", fn file ->
        assert file =~ ~s(= text_input f, :title, class: "form-control")
        assert file =~ ~s(= number_input f, :votes, class: "form-control")
        assert file =~ ~s(= number_input f, :cost, step: "any", class: "form-control")
        assert file =~ ~s(= checkbox f, :popular, class: "checkbox")
        assert file =~ ~s(= label f, :title, class: "control-label")
        assert file =~ ~s(= error_tag f, :title)

        refute file =~ ":user_id"
        refute file =~ ":tags"
      end

      assert_file "lib/phoenix_slime_web/templates/post/index.html.slime", fn file ->
        assert file =~ "h2 Listing Posts"
        assert file =~ "th Title"
        assert file =~ "= for post <- @posts do"
        assert file =~ "td= post.title"
      end

      assert_file "lib/phoenix_slime_web/templates/post/new.html.slime", fn file ->
        assert file =~ "h2 New Post"
        assert file =~ "action, post_path(@conn, :create)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/show.html.slime", fn file ->
        assert file =~ "strong Title:"
        assert file =~ "= @post.title"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/posts", PostController)
    end
  end

  test "generates html resource with web namespace" do
    in_tmp "phx generates namespaced html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post posts title:string --web Admin)

      assert_file "lib/phoenix_slime_web/controllers/admin/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Admin.PostController"
      end

      assert_file "lib/phoenix_slime_web/templates/admin/post/index.html.slime", fn file ->
        assert file =~ "admin_post_path(@conn, :new)"
      end
    end
  end

  test "generates html resource without context" do
    in_tmp "phx generates html resource without context", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post posts title:string --no-context)

      refute_file "lib/phoenix_slime/blog/blog.ex"
      refute_file "lib/phoenix_slime/blog/post.ex"
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
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post posts title:string)

        for name <- ~w(edit form index new show) do
          assert_file "lib/phoenix_slime_web/templates/post/#{name}.html.slim"
        end
      end
    end
  end
end
