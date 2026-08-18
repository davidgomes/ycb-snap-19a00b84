defmodule Newsletter.EmailsTest do
  use ExUnit.Case

  alias Newsletter.Emails

  test "welcome/1 creates a welcome email for a user" do
    user = %{name: "Alice", email: "alice@example.com"}
    email = Emails.welcome(user)

    assert email.to == [{"Alice", "alice@example.com"}]
    assert email.from == {"Brooklin", "brooklin.myers@dockyard.com"}
    assert email.subject == "Welcome to the DockYard Academy Newsletter"
    assert email.html_body =~ "Alice"
    assert email.text_body =~ "Alice"
  end
end
