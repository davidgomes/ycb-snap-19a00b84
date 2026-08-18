Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.Html.SlimeTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates html resource and handles existing contexts" do
    in_tmp_project "generates html resource", fn ->
      Gen.Html.Slime.run(~w(Blog Post posts title slug:unique votes:integer cost:decimal
                            tags:array:text popular:boolean drafted_at:datetime
                            published_at:utc_datetime deleted_at:naive_datetime
                            secret:uuid announcement_date:date alarm:time
                            weight:float user_id:references:users))

      assert_file "lib/phoenix_slime/blog/post.ex"
      assert_file "lib/phoenix_slime/blog/blog.ex"
      assert_file "test/phoenix_slime/blog/blog_test.exs", fn file ->
        assert file =~ "alarm: ~T[15:01:01.000000]"
        assert file =~ "announcement_date: ~D[2010-04-17]"
        assert file =~ "deleted_at: ~N[2010-04-17 14:00:00.000000]"
        assert file =~ "cost: \"120.5\""
        assert file =~ "published_at: \"2010-04-17 14:00:00.000000Z\""
        assert file =~ "weight: 120.5"

        assert file =~ "assert post.announcement_date == ~D[2011-05-18]"
        assert file =~ "assert post.deleted_at == ~N[2011-05-18 15:01:01.000000]"
        assert file =~ "assert post.published_at == DateTime.from_naive!(~N[2011-05-18 15:01:01.000000Z], \"Etc/UTC\")"
        assert file =~ "assert post.alarm == ~T[15:01:01.000000]"
        assert file =~ "assert post.cost == Decimal.new(\"120.5\")"
        assert file =~ "assert post.weight == 120.5"
      end

      assert_file "test/phoenix_slime_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostControllerTest"
        assert file =~ " post_path(conn"
      end

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
      end

      assert_file "lib/phoenix_slime_web/templates/post/edit.html.slime", fn file ->
        assert file =~ " post_path(@conn"
        assert file =~ "= render \"form.html\", Map.put(assigns, :action, post_path(@conn, :update, @post))"
        assert file =~ "span= link \"Back\", to: post_path(@conn, :index)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/index.html.slime", fn file ->
        assert file =~ "th Title"
        assert file =~ "= for post <- @posts do"
        assert file =~ "td= post.title"
        assert file =~ "span= link \"Show\", to: post_path(@conn, :show, post), class: \"btn btn-default btn-xs\""
        assert file =~ "span= link \"Edit\", to: post_path(@conn, :edit, post), class: \"btn btn-default btn-xs\""
        assert file =~ "span= link \"Delete\", to: post_path(@conn, :delete, post), method: :delete, data: [confirm: \"Are you sure?\"], class: \"btn btn-danger btn-xs\""
        assert file =~ "span= link \"New Post\", to: post_path(@conn, :new)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/new.html.slime", fn file ->
        assert file =~ " post_path(@conn"
        assert file =~ "= render \"form.html\", Map.put(assigns, :action, post_path(@conn, :create))"
        assert file =~ "span= link \"Back\", to: post_path(@conn, :index)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/show.html.slime", fn file ->
        assert file =~ "strong Title:&nbsp;"
        assert file =~ "= @post.title"
        assert file =~ "span= link \"Edit\", to: post_path(@conn, :edit, @post)"
        assert file =~ "span= link \"Back\", to: post_path(@conn, :index)"
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
        assert file =~ ~s(= label f, :votes, class: "control-label")
        assert file =~ ~s(= label f, :cost, class: "control-label")
        assert file =~ ~s(= label f, :popular, class: "control-label")
        assert file =~ ~s(= label f, :drafted_at, class: "control-label")
        assert file =~ ~s(= label f, :published_at, class: "control-label")
        assert file =~ ~s(= label f, :deleted_at, class: "control-label")
        assert file =~ ~s(= label f, :announcement_date, class: "control-label")
        assert file =~ ~s(= label f, :alarm, class: "control-label")
        assert file =~ ~s(= label f, :secret, class: "control-label")

        refute file =~ ":tags"
        refute file =~ ~s(= label f, :user_id)
        refute file =~ ~s(= number_input f, :user_id)
      end

      Gen.Html.Slime.run(~w(Blog Comment comments title:string))
      assert_file "lib/phoenix_slime/blog/comment.ex"

      assert_file "test/phoenix_slime_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.CommentControllerTest"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:comments)"
        assert file =~ "add :title, :string"
      end

      assert_file "lib/phoenix_slime_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.CommentController"
        assert file =~ "use PhoenixSlimeWeb, :controller"
        assert file =~ "Blog.get_comment!"
        assert file =~ "Blog.list_comments"
        assert file =~ "Blog.create_comment"
        assert file =~ "Blog.update_comment"
        assert file =~ "Blog.delete_comment"
        assert file =~ "Blog.change_comment"
        assert file =~ "redirect(to: comment_path(conn"
      end

      assert_receive {:mix_shell, :info, ["""

      Add the resource to your browser scope in lib/phoenix_slime_web/router.ex:

          resources "/posts", PostController
      """]}
    end
  end

  test "with --web namespace generates namespaced web modules and directories" do
    in_tmp_project "with --web namespace", fn ->
      Gen.Html.Slime.run(~w(Blog Post posts title:string --web Blog))

      assert_file "test/phoenix_slime_web/controllers/blog/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostControllerTest"
        assert file =~ " blog_post_path(conn"
      end

      assert_file "lib/phoenix_slime_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostController"
        assert file =~ "use PhoenixSlimeWeb, :controller"
        assert file =~ "redirect(to: blog_post_path(conn"
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

      assert_file "lib/phoenix_slime_web/views/blog/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.Blog.PostView"
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

  describe "when :use_slim_extension env is set to true" do
    setup do
      Application.put_env(:phoenix_slime, :use_slim_extension, true)
      on_exit fn ->
        Application.delete_env(:phoenix_slime, :use_slim_extension)
      end
      :ok
    end

    test "generates files with .slim extension " do
      in_tmp_project "generates .slim", fn ->
        Gen.Html.Slime.run(~w(Blog Post posts title:string))

        assert File.exists? "lib/phoenix_slime_web/templates/post/edit.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/form.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/index.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/new.html.slim"
        assert File.exists? "lib/phoenix_slime_web/templates/post/show.html.slim"
      end
    end
  end
end
