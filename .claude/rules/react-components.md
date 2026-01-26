---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/components/**/*"
---

# React Component Development

When creating or modifying React components, apply these skills:
- **react** - React 19 patterns, hooks, Server Components, Suspense, async components
- **ui-styling** - shadcn/ui components, Tailwind, theming, forms

## Component-First Principle

**Never use shadcn/ui primitives directly in pages or features.**

Instead:
1. Create custom wrapper components in `components/custom/`
2. Import and use the custom component everywhere

```tsx
// WRONG - primitive used directly
import { Button } from "@/components/ui/button"
<Button variant="default" className="bg-brand">Save</Button>

// CORRECT - custom wrapper
import { AppButton } from "@/components/custom/app-button"
<AppButton isLoading={isPending}>Save</AppButton>
```

## React 19 Patterns

### Hooks Priority
- `use()` for promises/context
- `useOptimistic()` for optimistic updates
- `useActionState()` for form actions
- `useTransition()` for non-blocking updates

### Data Fetching
```tsx
// Prefer: useSuspenseQuery with Suspense boundary
<Suspense fallback={<Skeleton />}>
  <DataComponent />
</Suspense>

// Inside component
const { data } = useSuspenseQuery({ queryKey: ['data'], queryFn })
```

### Server vs Client
- Default to Server Components (no 'use client')
- Add 'use client' only for: useState, useEffect, event handlers, browser APIs

## Mobile-First Styling

- Base styles (no prefix) = mobile
- Add `sm:`, `md:`, `lg:` for larger viewports
- Use `min-h-11` (44px) for touch targets

## Reference Skills

Invoke for detailed patterns:
- **react** - Hooks, Server Components, async patterns, TanStack Query
- **ui-styling** - CVA variants, form integration, compound components
