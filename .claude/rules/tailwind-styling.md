---
paths:
  - "**/tailwind.config.*"
  - "**/globals.css"
  - "**/*.css"
  - "**/styles/**/*"
---

# Tailwind CSS Styling

When working with Tailwind configuration or CSS files, apply the **ui-styling** skill.

## Mobile-First Breakpoints

| Prefix | Min-width | Use |
|--------|-----------|-----|
| (none) | 0px | Mobile base styles |
| `sm:` | 640px | Large phones |
| `md:` | 768px | Tablets |
| `lg:` | 1024px | Laptops |
| `xl:` | 1280px | Desktops |

## CSS Variables for Theming

Define colors as RGB values (no `rgb()` wrapper) for alpha support:

```css
:root {
  --color-primary: 59 130 246;
  --color-background: 255 255 255;
}
.dark {
  --color-background: 2 6 23;
}
```

Reference in tailwind.config:
```ts
colors: {
  primary: 'rgb(var(--color-primary) / <alpha-value>)',
}
```

## Touch-Friendly Defaults

- Buttons/inputs: `min-h-11` (44px)
- Icon buttons: `p-2.5` with `h-5 w-5` icons
- List items: `py-3` minimum

## Reference

For complete patterns, invoke the `ui-styling` skill.
