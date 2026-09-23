### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content. The `MyAppWeb.Layouts` module is already aliased in the `my_app_web.ex` file
- Anytime you run into errors with no `current_scope` assign, you either failed to follow the Authentication guidelines or failed to pass `current_scope` to `<Layouts.app>`. **Always** fix it by moving your routes to the proper `live_session` and passing `current_scope` as needed
- The `<.flash_group>` component lives in the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- **Always** use the `<.icon name="hero-x-mark" class="w-5 h-5"/>` component from `core_components.ex` for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component from `core_components.ex` for form inputs. If you pass your own `class` (`<.input class="myclass px-2 py-1 rounded-lg">`), no default classes are inherited, so your custom classes must fully style the input
