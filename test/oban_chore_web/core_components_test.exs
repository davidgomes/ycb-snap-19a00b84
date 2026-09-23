defmodule ObanChoreWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveViewTest
  import ObanChoreWeb.CoreComponents

  describe "input/1" do
    test "renders a labelled input bound to a form field" do
      form = to_form(%{"reason" => "Manual fix"}, as: :args)

      html = render_component(&input/1, field: form[:reason], label: "Reason", type: "text")

      assert html =~ ~s(<label for="args_reason" class="oc-label">)
      assert html =~ "Reason"
      assert html =~ ~s(type="text")
      assert html =~ ~s(name="args[reason]")
      assert html =~ ~s(id="args_reason")
      assert html =~ ~s(value="Manual fix")
    end

    test "falls back to the default when the field has no value" do
      form = to_form(%{}, as: :args)

      html = render_component(&input/1, field: form[:sleep_time], type: "number", default: 3000)

      assert html =~ ~s(value="3000")
    end

    test "renders field errors with their options interpolated" do
      form =
        to_form(%{"age" => "15"},
          as: :args,
          errors: [age: {"must be greater than %{number}", [number: 18]}]
        )

      html = render_component(&input/1, field: form[:age], type: "number")

      assert html =~ "must be greater than 18"
    end

    test "renders a checkbox with a hidden false value" do
      form = to_form(%{"notify" => true}, as: :args)

      html = render_component(&input/1, field: form[:notify], type: "checkbox", label: "Notify?")

      assert html =~ ~s(<input type="hidden" name="args[notify]" value="false">)
      assert html =~ ~s(type="checkbox")
      assert html =~ ~s(value="true")
      assert html =~ "checked"
      assert html =~ "Notify?"
    end

    test "leaves the checkbox unchecked when the value is false" do
      form = to_form(%{"notify" => false}, as: :args)

      html = render_component(&input/1, field: form[:notify], type: "checkbox")

      refute html =~ "checked"
    end

    test "renders a textarea with its value" do
      form = to_form(%{"notes" => "Some long text"}, as: :args)

      html = render_component(&input/1, field: form[:notes], type: "textarea")

      assert html =~ ~s(<textarea id="args_notes" name="args[notes]" class="oc-input">)
      assert html =~ "Some long text</textarea>"
    end

    test "renders a select with a prompt and the current value selected" do
      form = to_form(%{"role" => "2"}, as: :args)

      html =
        render_component(&input/1,
          field: form[:role],
          type: "select",
          options: [Admin: 1, Editor: 2],
          prompt: "Choose a role..."
        )

      assert html =~ ~s(<select id="args_role" name="args[role]" class="oc-input">)
      assert html =~ ~s(<option value="">Choose a role...</option>)
      assert html =~ ~s(<option value="1">Admin</option>)
      assert html =~ ~s(<option selected value="2">Editor</option>)
    end

    test "formats date, time and datetime values for their HTML inputs" do
      form =
        to_form(
          %{
            "run_on" => ~D[2024-05-06],
            "run_at" => ~T[13:45:30],
            "starts_at" => ~U[2024-05-06 13:45:30Z]
          },
          as: :args
        )

      assert render_component(&input/1, field: form[:run_on], type: "date") =~
               ~s(value="2024-05-06")

      assert render_component(&input/1, field: form[:run_at], type: "time") =~
               ~s(value="13:45")

      assert render_component(&input/1, field: form[:starts_at], type: "datetime-local") =~
               ~s(value="2024-05-06T13:45")
    end
  end

  describe "badge/1" do
    test "renders the count when it is positive" do
      html = render_component(&badge/1, count: 3)

      assert html =~ "oc-badge-blue"
      assert html =~ "3"
    end

    test "renders nothing when the count is zero" do
      assert render_component(&badge/1, count: 0) |> String.trim() == ""
    end
  end

  describe "duplicate_warning_banner/1" do
    test "wires the confirm and cancel buttons to the given events and target" do
      html =
        render_component(&duplicate_warning_banner/1,
          on_confirm: "confirm_execute",
          on_cancel: "cancel_execute",
          "phx-target": "#my-chore"
        )

      assert html =~ "Duplicate Execution Warning"
      assert html =~ ~s(phx-click="confirm_execute" phx-target="#my-chore")
      assert html =~ ~s(phx-click="cancel_execute" phx-target="#my-chore")
    end
  end

  describe "unique_execution_toggle/1" do
    test "can be toggled when the worker does not define uniqueness" do
      html =
        render_component(&unique_execution_toggle/1,
          unique_execution: true,
          worker_has_unique: false
        )

      assert html =~ ~s(phx-click="toggle_unique")
      assert html =~ "checked"
      refute html =~ "disabled"
      assert html =~ "uniqueness engine"
    end

    test "is disabled when the worker enforces its own uniqueness" do
      html =
        render_component(&unique_execution_toggle/1,
          unique_execution: true,
          worker_has_unique: true
        )

      refute html =~ "phx-click"
      assert html =~ "disabled"
      assert html =~ "Uniqueness is enforced by the worker definition."
    end
  end

  describe "flash_group/1" do
    test "renders info and error messages" do
      html = render_component(&flash_group/1, flash: %{"info" => "Job enqueued"})

      assert html =~ "Success!"
      assert html =~ "Job enqueued"
      refute html =~ "Error!"

      html = render_component(&flash_group/1, flash: %{"error" => "Failed to enqueue"})

      assert html =~ "Error!"
      assert html =~ "Failed to enqueue"
      refute html =~ "Success!"
    end
  end
end
