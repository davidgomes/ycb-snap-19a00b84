Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.Html.SlimeTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear
    :ok
  end

  test "invalid mix arguments" do
    in_tmp "phx invalid mix arguments", fn ->
      assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
        Gen.Html.Slime.run(~w(blog Post posts title:string))
      end

      assert_raise Mix.Error, ~r/Expected the schema, "posts", to be a valid module name/, fn ->
        Gen.Html.Slime.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Html.Slime.run(~w(Blog Blog blogs))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Html.Slime.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Html.Slime.run(~w(Blog Post))
      end
    end
  end

  test "generates html resource and handles existing contexts" do
    in_tmp "phx generates html resource", fn ->
      Gen.Html.Slime.run(~w(Blog Post posts title slug:unique votes:integer cost:decimal
                            tags:array:text popular:boolean published_at:utc_datetime
                            deleted_at:naive_datetime secret:uuid announcement_date:date
                            alarm:time weight:float user_id:references:users))

      assert_file "lib/phoenix_slime/blog/post.ex"
      assert_file "lib/phoenix_slime/blog/blog.ex"
      assert_file "test/phoenix_slime/blog/blog_test.exs"

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
        assert file =~ "create unique_index(:posts, [:slug])"
      end

      assert_file "lib/phoenix_slime_web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostController"
        assert file =~ "use PhoenixSlimeWeb, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
        assert file =~ "Blog.change_post"
        assert file =~ "redirect(to: post_path(conn"
      end

      assert_file "lib/phoenix_slime_web/views/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostView"
        assert file =~ "use PhoenixSlimeWeb, :view"
      end

      assert_file "test/phoenix_slime_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostControllerTest"
        assert file =~ " post_path(conn"
      end

      refute_file "lib/phoenix_slime_web/templates/post/edit.html.eex"

      assert_file "lib/phoenix_slime_web/templates/post/edit.html.slime", fn file ->
        assert file =~ "h2 Edit Post"
        assert file =~ ~s(= render "form.html", Map.put(assigns, :action, post_path(@conn, :update, @post)))
        assert file =~ ~s(= link "Back", to: post_path(@conn, :index))
      end

      assert_file "lib/phoenix_slime_web/templates/post/form.html.slime", fn file ->
        assert file =~ "= form_for @changeset, @action, fn f ->"
        assert file =~ ~s(= text_input f, :title, class: "form-control")
        assert file =~ ~s(= number_input f, :votes, class: "form-control")
        assert file =~ ~s(= number_input f, :cost, step: "any", class: "form-control")
        assert file =~ ~s(= number_input f, :weight, step: "any", class: "form-control")
        assert file =~ ~s(= checkbox f, :popular, class: "checkbox")
        assert file =~ ~s(= datetime_select f, :published_at, class: "form-control")
        assert file =~ ~s(= datetime_select f, :deleted_at, class: "form-control")
        assert file =~ ~s(= date_select f, :announcement_date, class: "form-control")
        assert file =~ ~s(= time_select f, :alarm, class: "form-control")
        assert file =~ ~s(= text_input f, :secret, class: "form-control")

        assert file =~ ~s(= label f, :title, class: "control-label")
        assert file =~ ~s(= label f, :votes, class: "control-label")
        assert file =~ ~s(= label f, :popular, class: "control-label")
        assert file =~ ~s(= label f, :announcement_date, class: "control-label")
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
        assert file =~ "post_path(@conn, :show, post)"
        assert file =~ ~s(= link "New Post", to: post_path(@conn, :new))
      end

      assert_file "lib/phoenix_slime_web/templates/post/new.html.slime", fn file ->
        assert file =~ "h2 New Post"
        assert file =~ ~s(= render "form.html", Map.put(assigns, :action, post_path(@conn, :create)))
      end

      assert_file "lib/phoenix_slime_web/templates/post/show.html.slime", fn file ->
        assert file =~ "h2 Show Post"
        assert file =~ "strong Title:"
        assert file =~ "= @post.title"
        assert file =~ ~s(= link "Edit", to: post_path(@conn, :edit, @post))
      end

      Gen.Html.Slime.run(~w(Blog Comment comments title:string))
      assert_file "lib/phoenix_slime/blog/comment.ex"

      assert_file "lib/phoenix_slime/blog/blog.ex", fn file ->
        assert file =~ "def list_posts"
        assert file =~ "def list_comments"
      end

      assert_file "lib/phoenix_slime_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.CommentController"
        assert file =~ "Blog.list_comments"
      end

      assert_file "lib/phoenix_slime_web/templates/comment/form.html.slime"

      assert_receive {:mix_shell, :info, ["""

      Add the resource to your browser scope in lib/phoenix_slime_web/router.ex:

          resources "/posts", PostController
      """]}
    end
  end

  test "with --web namespace generates namespaced web modules and directories" do
    in_tmp "phx generates web namespace", fn ->
      Gen.Html.Slime.run(~w(Blog Post posts title:string --web Blog))

      assert_file "test/phoenix_slime_web/controllers/blog/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostControllerTest"
        assert file =~ " blog_post_path(conn"
      end

      assert_file "lib/phoenix_slime_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostController"
        assert file =~ "redirect(to: blog_post_path(conn"
      end

      assert_file "lib/phoenix_slime_web/views/blog/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostView"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/form.html.slime"

      assert_file "lib/phoenix_slime_web/templates/blog/post/edit.html.slime", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/index.html.slime", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/new.html.slime", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_file "lib/phoenix_slime_web/templates/blog/post/show.html.slime", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_receive {:mix_shell, :info, ["""

      Add the resource to your Blog :browser scope in lib/phoenix_slime_web/router.ex:

          scope "/blog", PhoenixSlimeWeb.Blog, as: :blog do
            pipe_through :browser
            ...
            resources "/posts", PostController
          end
      """]}
    end
  end

  test "with --no-context skips context and schema file generation" do
    in_tmp "phx generates without context", fn ->
      Gen.Html.Slime.run(~w(Blog Comment comments title:string --no-context))

      refute_file "lib/phoenix_slime/blog/blog.ex"
      refute_file "lib/phoenix_slime/blog/comment.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "lib/phoenix_slime_web/controllers/comment_controller.ex"
      assert_file "lib/phoenix_slime_web/views/comment_view.ex"
      assert_file "lib/phoenix_slime_web/templates/comment/form.html.slime"
      assert_file "test/phoenix_slime_web/controllers/comment_controller_test.exs"
    end
  end

  test "with --no-schema skips schema file generation" do
    in_tmp "phx generates without schema", fn ->
      Gen.Html.Slime.run(~w(Blog Comment comments title:string --no-schema))

      assert_file "lib/phoenix_slime/blog/blog.ex"
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
        Gen.Html.Slime.run(~w(Accounts User users name:string))

        assert_file "lib/phoenix_slime_web/templates/user/edit.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/form.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/index.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/new.html.slim"
        assert_file "lib/phoenix_slime_web/templates/user/show.html.slim"
      end
    end
  end
end
