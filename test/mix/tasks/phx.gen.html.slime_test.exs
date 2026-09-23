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
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post posts title slug:unique votes:integer cost:decimal
                                          tags:array:text popular:boolean drafted_at:datetime
                                          published_at:utc_datetime deleted_at:naive_datetime
                                          secret:uuid announcement_date:date alarm:time
                                          weight:float user_id:references:users)

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
        assert file =~ "defmodule PhoenixSlimeWeb.PostView"
      end

      assert_file "test/phoenix_slime_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostControllerTest"
      end

      assert_file "lib/phoenix_slime_web/templates/post/edit.html.slime", fn file ->
        assert file =~ "h2 Edit Post"
        assert file =~ "post_path(@conn, :update, @post)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/form.html.slime", fn file ->
        assert file =~ ~s(= text_input f, :title, class: "form-control")
        assert file =~ ~s(= number_input f, :votes, class: "form-control")
        assert file =~ ~s(= number_input f, :cost, step: "any", class: "form-control")
        assert file =~ ~s(= checkbox f, :popular, class: "checkbox")
        assert file =~ ~s(= datetime_select f, :drafted_at, class: "form-control")
        assert file =~ ~s(= datetime_select f, :published_at, class: "form-control")
        assert file =~ ~s(= datetime_select f, :deleted_at, class: "form-control")
        assert file =~ ~s(= date_select f, :announcement_date, class: "form-control")
        assert file =~ ~s(= time_select f, :alarm, class: "form-control")
        assert file =~ ~s(= text_input f, :secret, class: "form-control")
        assert file =~ ~s(= label f, :title, class: "control-label")
        assert file =~ ~s(= error_tag f, :title)

        refute file =~ ":tags"
        refute file =~ ~s(= label f, :user_id)
        refute file =~ ~s(= number_input f, :user_id)
      end

      assert_file "lib/phoenix_slime_web/templates/post/index.html.slime", fn file ->
        assert file =~ "h2 Listing Posts"
        assert file =~ "th Title"
        assert file =~ "= for post <- @posts do"
        assert file =~ "td= post.title"
      end

      assert_file "lib/phoenix_slime_web/templates/post/new.html.slime", fn file ->
        assert file =~ "h2 New Post"
        assert file =~ "post_path(@conn, :create)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/show.html.slime", fn file ->
        assert file =~ "h2 Show Post"
        assert file =~ "strong Title:"
        assert file =~ "= @post.title"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/posts", PostController)
    end
  end

  test "with --web namespace generates namespaced web modules and directories" do
    in_tmp "phx generates namespaced html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post posts title:string --web Blog)

      assert_file "lib/phoenix_slime_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostController"
      end

      assert_file "lib/phoenix_slime_web/views/blog/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostView"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/form.html.slime"

      assert_file "lib/phoenix_slime_web/templates/blog/post/edit.html.slime", fn file ->
        assert file =~ "blog_post_path(@conn, :update, @post)"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/index.html.slime", fn file ->
        assert file =~ "blog_post_path(@conn, :show, post)"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/new.html.slime", fn file ->
        assert file =~ "blog_post_path(@conn, :create)"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/show.html.slime", fn file ->
        assert file =~ "blog_post_path(@conn, :edit, @post)"
      end
    end
  end

  test "with --no-context skips context and schema file generation" do
    in_tmp "phx generates html resource without context", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Comment comments title:string --no-context)

      refute_file "lib/phoenix_slime/blog/blog.ex"
      refute_file "lib/phoenix_slime/blog/comment.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "lib/phoenix_slime_web/controllers/comment_controller.ex"
      assert_file "lib/phoenix_slime_web/templates/comment/form.html.slime"
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

        assert File.exists? "lib/phoenix_slime_web/templates/post/edit.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/form.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/index.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/new.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/show.html.slim"
      end
    end
  end

  test "invalid mix arguments" do
    in_tmp "phx invalid mix arguments", fn ->
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(blog Post posts title:string)
      end

      assert_raise Mix.Error, fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ~w(Blog Post)
      end
    end
  end
end
