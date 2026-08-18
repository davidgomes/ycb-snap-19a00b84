defmodule PetalComponents.PopoverTest do
  use ComponentCase
  import PetalComponents.Popover

  test "renders trigger and hidden panel with default bottom placement" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.popover id="pop-basic">
        <:trigger>Open</:trigger>
        Panel content
      </.popover>
      """)

    assert html =~ "Open"
    assert html =~ "Panel content"
    assert html =~ "pc-popover"
    assert html =~ "pc-popover__panel--bottom"
    assert html =~ ~s(style="display: none;")
    assert html =~ ~s(role="dialog")
    assert html =~ ~s(aria-controls="pop-basic")
    assert html =~ ~s(aria-haspopup="dialog")
    assert html =~ "phx-click-away"
    assert html =~ ~s(phx-key="Escape")
  end

  test "trigger has an id and toggles aria-expanded, Escape returns focus" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.popover id="pop-a11y">
        <:trigger>Open</:trigger>
        Panel
      </.popover>
      """)

    assert html =~ ~s(id="pop-a11y-trigger")
    assert html =~ ~s(aria-expanded="false")
    # the click command toggles aria-expanded alongside the panel
    assert html =~ "toggle_attr"
    # the Escape binding is scoped to the component and returns focus to the trigger
    assert html =~ "phx-keydown"
    refute html =~ "phx-window-keydown"
    assert html =~ ~s(focus)
    assert html =~ "pop-a11y-trigger"
  end

  test "generates an id when not given" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.popover>
        <:trigger>Open</:trigger>
        Panel
      </.popover>
      """)

    assert html =~ ~s(id="popover_)
  end

  test "supports side and alignment placements including right-start" do
    assigns = %{}

    for placement <- ["top-start", "bottom-end", "right-start", "left-end"] do
      assigns = Map.put(assigns, :placement, placement)

      html =
        rendered_to_string(~H"""
        <.popover placement={@placement}>
          <:trigger>Open</:trigger>
          Panel
        </.popover>
        """)

      assert html =~ "pc-popover__panel--#{placement}"
    end
  end

  test "top_layer renders a native popover wired to the trigger with the positioning hook" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.popover id="pop-top" top_layer placement="right-start">
        <:trigger>Open</:trigger>
        Panel content
      </.popover>
      """)

    assert html =~ ~s(popover="auto")
    assert html =~ ~s(popovertarget="pop-top")
    assert html =~ ~s(phx-hook="PetalPopover")
    assert html =~ ~s(data-placement="right-start")
    assert html =~ "pc-popover__panel--top-layer"
    refute html =~ ~s(style="display: none;")
    refute html =~ "phx-click-away"
  end

  test "hide_popover/2 hides the panel and resets the trigger's aria-expanded" do
    assigns = %{close: hide_popover("pop-close")}

    html =
      rendered_to_string(~H"""
      <form phx-submit={@close}></form>
      """)

    assert html =~ "&quot;hide&quot;"
    assert html =~ "#pop-close&quot;"
    assert html =~ "&quot;aria-expanded&quot;,&quot;false&quot;"
    assert html =~ "#pop-close-trigger&quot;"
  end

  test "hide_popover/2 composes onto commands passed in" do
    assigns = %{submit: Phoenix.LiveView.JS.push("save") |> hide_popover("pop-compose")}

    html =
      rendered_to_string(~H"""
      <form phx-submit={@submit}></form>
      """)

    assert html =~ "&quot;push&quot;"
    assert html =~ "&quot;save&quot;"
    assert html =~ "&quot;hide&quot;"
  end

  test "passes through custom classes" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.popover class="wrapper-custom" trigger_class="trigger-custom" panel_class="panel-custom">
        <:trigger>Open</:trigger>
        Panel
      </.popover>
      """)

    assert html =~ "wrapper-custom"
    assert html =~ "trigger-custom"
    assert html =~ "panel-custom"
  end
end
