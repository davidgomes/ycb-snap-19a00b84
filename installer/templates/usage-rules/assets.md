### JS and CSS guidelines

- Tailwind CSS v4 **no longer needs a `tailwind.config.js`** and uses a new import syntax in `app.css`, which you must **always use and maintain**:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Never** use `@apply` when writing raw CSS
- **Always** write your own Tailwind-based components instead of using daisyUI, for a unique design
- Out of the box **only the `app.js` and `app.css` bundles are supported**. You cannot reference external vendored scripts or stylesheets in the layouts, import vendor deps into `app.js` and `app.css` instead. **Never** write inline `<script>` tags within templates

### UI/UX & design guidelines

- **Produce polished, responsive, world-class UI designs** using Tailwind CSS classes and custom CSS rules, with a focus on usability and modern design principles
- Ensure **clean typography, spacing, and layout balance**
- Add **delightful details** like subtle hover effects, loading states, and smooth transitions
