Code.require_file "../mix_helper.exs", __DIR__

defmodule PhoenixSlimeWeb.DupHTMLController do
end

defmodule PhoenixSlimeWeb.DupHTMLView do
end

defmodule Mix.Tasks.Phx.Gen.Html.SlimeTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates html resource" do
    in_tmp "generates html resource", fn ->
      Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts", "title:string", "cost:decimal",
                                        "stars:integer", "views:integer", "published:boolean",
                                        "body:text", "published_at:naive_datetime",
                                        "first_login:date", "alarm:time"]

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

      assert_file "lib/phoenix_slime_web/templates/post/edit.html.slime", fn file ->
        assert file =~ "action: post_path(@conn, :update, @post)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/form.html.slime", fn file ->
        assert file =~ ~s(= text_input f, :title, class: "form-control")
        assert file =~ ~s(= number_input f, :cost, step: "any", class: "form-control")
        assert file =~ ~s(= number_input f, :stars, class: "form-control")
        assert file =~ ~s(= checkbox f, :published, class: "form-control")
        assert file =~ ~s(= textarea f, :body, class: "form-control")
        assert file =~ ~s(= datetime_select f, :published_at, class: "form-control")
        assert file =~ ~s(= date_select f, :first_login, class: "form-control")
        assert file =~ ~s(= time_select f, :alarm, class: "form-control")
        assert file =~ ~s(= label f, :title, class: "control-label")
        assert file =~ ~s(= label f, :cost, class: "control-label")
        assert file =~ ~s(= label f, :stars, class: "control-label")
        assert file =~ ~s(= label f, :published, class: "control-label")
        assert file =~ ~s(= label f, :body, class: "control-label")
        assert file =~ ~s(= label f, :published_at, class: "control-label")
      end

      assert_file "lib/phoenix_slime_web/templates/post/index.html.slime", fn file ->
        assert file =~ "th Title"
        assert file =~ "= for post <- @posts do"
        assert file =~ "td= post.title"
      end

      assert_file "lib/phoenix_slime_web/templates/post/new.html.slime", fn file ->
        assert file =~ "action: post_path(@conn, :create)"
      end

      assert_file "lib/phoenix_slime_web/templates/post/show.html.slime", fn file ->
        assert file =~ "strong Title:"
        assert file =~ "= @post.title"
      end

      assert_file "test/phoenix_slime_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixSlimeWeb.PostControllerTest"
        assert file =~ "use PhoenixSlimeWeb.ConnCase"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/posts", PostController)
    end
  end

  describe "when :use_slim_extension env is set to true" do
    setup do
      Application.put_env(:phoenix_slime, :use_slim_extension, true)
      on_exit(fn ->
        Application.delete_env(:phoenix_slime, :use_slim_extension)
      end)
      :ok
    end

    test "generates files with .slim extension " do
      in_tmp "generates .slim", fn ->
        Mix.Tasks.Phx.Gen.Html.Slime.run ["Blog", "Post", "posts", "title:string"]

        assert File.exists?("lib/phoenix_slime_web/templates/post/edit.html.slim")
        assert File.exists?("lib/phoenix_slime_web/templates/post/form.html.slim")
        assert File.exists?("lib/phoenix_slime_web/templates/post/index.html.slim")
        assert File.exists?("lib/phoenix_slime_web/templates/post/new.html.slim")
        assert File.exists?("lib/phoenix_slime_web/templates/post/show.html.slim")
      end
    end
  end
end
