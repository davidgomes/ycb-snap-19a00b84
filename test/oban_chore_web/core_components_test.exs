defmodule ObanChoreWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest

  alias ObanChoreWeb.CoreComponents

  describe "input/1" do
    test "renders a labelled text input for a form field" do
      form = to_form(%{"name" => "Ada"}, as: :args)

      html = render_component(&CoreComponents.input/1, field: form[:name], label: "Name")

      assert html =~ ~s(<label for="args_name" class="oc-label">)
      assert html =~ "Name"
      assert html =~ ~s(<input type="text" name="args[name]" id="args_name" value="Ada")
    end

    test "falls back to the default when the field has no value" do
      form = to_form(%{}, as: :args)

      html = render_component(&CoreComponents.input/1, field: form[:reason], default: "Manual")

      assert html =~ ~s(name="args[reason]")
      assert html =~ ~s(value="Manual")
    end

    test "renders the field's errors" do
      form =
        to_form(%{"name" => "Al"},
          as: :args,
          errors: [name: {"should be at least %{count} character(s)", [count: 5]}]
        )

      html = render_component(&CoreComponents.input/1, field: form[:name])

      assert html =~ "should be at least 5 character(s)"
    end

    test "renders a checkbox that submits false when unchecked" do
      form = to_form(%{"notify" => true, "silent" => false}, as: :args)

      checked =
        render_component(&CoreComponents.input/1,
          field: form[:notify],
          type: "checkbox",
          label: "Notify?"
        )

      assert checked =~ ~s(<input type="hidden" name="args[notify]" value="false">)
      assert checked =~ ~r/<input type="checkbox"[^>]* value="true" checked/
      assert checked =~ "Notify?"

      unchecked =
        render_component(&CoreComponents.input/1, field: form[:silent], type: "checkbox")

      refute unchecked =~ "checked"
    end

    test "renders a textarea with the field value" do
      form = to_form(%{"reason" => "Customer asked for a refund"}, as: :args)

      html = render_component(&CoreComponents.input/1, field: form[:reason], type: "textarea")

      assert html =~
               ~r{<textarea id="args_reason" name="args\[reason\]"[^>]*>\s*Customer asked for a refund</textarea>}
    end

    test "renders a select with its prompt and the current value selected" do
      form = to_form(%{"role" => "2"}, as: :args)

      html =
        render_component(&CoreComponents.input/1,
          field: form[:role],
          type: "select",
          options: [Admin: 1, Editor: 2],
          prompt: "Choose a role..."
        )

      assert html =~ ~s(<select id="args_role" name="args[role]")
      assert html =~ ~s(<option value="">Choose a role...</option>)
      assert html =~ ~s(<option value="1">Admin</option>)
      assert html =~ ~s(<option selected value="2">Editor</option>)
    end

    test "formats date, time and datetime values for their HTML inputs" do
      form =
        to_form(
          %{"on" => ~D[2024-05-01], "at" => ~T[13:45:10], "run_at" => ~U[2024-05-01 13:45:10Z]},
          as: :args
        )

      date = render_component(&CoreComponents.input/1, field: form[:on], type: "date")
      time = render_component(&CoreComponents.input/1, field: form[:at], type: "time")

      datetime =
        render_component(&CoreComponents.input/1, field: form[:run_at], type: "datetime-local")

      assert date =~ ~s(<input type="date" name="args[on]" id="args_on" value="2024-05-01")
      assert time =~ ~s(<input type="time" name="args[at]" id="args_at" value="13:45")

      assert datetime =~
               ~s(<input type="datetime-local" name="args[run_at]" id="args_run_at" value="2024-05-01T13:45")
    end
  end

  describe "badge/1" do
    test "renders the count" do
      html = render_component(&CoreComponents.badge/1, count: 3)

      assert html =~ "oc-badge-blue"
      assert html =~ "3"
    end

    test "renders nothing when the count is zero" do
      assert render_component(&CoreComponents.badge/1, count: 0) == ""
    end
  end

  describe "unique_execution_toggle/1" do
    test "can be toggled when the worker doesn't define uniqueness" do
      html =
        render_component(&CoreComponents.unique_execution_toggle/1,
          unique_execution: false,
          worker_has_unique: false
        )

      assert html =~ ~s(phx-click="toggle_unique")
      refute html =~ "disabled"
      refute html =~ "checked"
      assert html =~ "Uses Oban's uniqueness engine"
    end

    test "is checked and disabled when the worker defines uniqueness" do
      html =
        render_component(&CoreComponents.unique_execution_toggle/1,
          unique_execution: true,
          worker_has_unique: true
        )

      assert html =~ ~r/<input type="checkbox"[^>]* checked disabled/
      refute html =~ "phx-click"
      assert html =~ "Uniqueness is enforced by the worker definition."
    end
  end

  test "duplicate_warning_banner/1 wires the confirm and cancel events to its target" do
    html =
      render_component(&CoreComponents.duplicate_warning_banner/1,
        on_confirm: "confirm_execute",
        on_cancel: "cancel_execute",
        "phx-target": "#chore"
      )

    assert html =~ "Duplicate Execution Warning"

    assert html =~
             ~s(<button type="button" phx-click="confirm_execute" phx-target="#chore" class="oc-btn oc-btn-warning">)

    assert html =~
             ~s(<button type="button" phx-click="cancel_execute" phx-target="#chore" class="oc-link-warning">)
  end

  describe "flash_group/1" do
    test "renders info and error messages" do
      html =
        render_component(&CoreComponents.flash_group/1,
          flash: %{"info" => "Successfully enqueued", "error" => "Failed to enqueue"}
        )

      assert html =~ ~s(id="flash-info")
      assert html =~ "Success!"
      assert html =~ "Successfully enqueued"
      assert html =~ ~s(id="flash-error")
      assert html =~ "Error!"
      assert html =~ "Failed to enqueue"
    end

    test "renders no messages when the flash is empty" do
      html = render_component(&CoreComponents.flash_group/1, flash: %{})

      refute html =~ "flash-info"
      refute html =~ "flash-error"
    end
  end
end
