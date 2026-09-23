defmodule Newsletter.EmailsTest do
  use ExUnit.Case, async: true

  alias Newsletter.Emails

  describe "welcome/1" do
    test "addresses the email to the user" do
      email = Emails.welcome(%{name: "Jane Doe", email: "jane@example.com"})

      assert email.to == [{"Jane Doe", "jane@example.com"}]
      assert email.subject == "Welcome to the DockYard Academy Newsletter"
      assert email.html_body == "<h1>Hello Jane Doe</h1>"
      assert email.text_body == "Hello Jane Doe"
    end

    test "escapes the user's name in the HTML body" do
      email = Emails.welcome(%{name: "<a href=\"https://evil.test\">x</a>", email: "a@b.c"})

      refute email.html_body =~ "<a "
      assert email.html_body =~ "&lt;a href=&quot;https://evil.test&quot;&gt;x&lt;/a&gt;"
    end
  end
end
