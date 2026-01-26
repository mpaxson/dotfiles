# Custom Component Patterns

Patterns for wrapping shadcn/ui primitives into reusable custom components.

## Basic Wrapper Pattern

Extend primitive with custom defaults and additional props:

```tsx
// components/custom/app-button.tsx
import { Button, type ButtonProps } from "@/components/ui/button"
import { Loader2 } from "lucide-react"
import { cn } from "@/lib/utils"

interface AppButtonProps extends ButtonProps {
  isLoading?: boolean
}

export function AppButton({
  isLoading,
  children,
  className,
  disabled,
  ...props
}: AppButtonProps) {
  return (
    <Button
      className={cn("min-h-11", className)}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
      {children}
    </Button>
  )
}
```

## CVA Variants Pattern

Use `class-variance-authority` for multiple visual variants:

```tsx
// components/custom/status-badge.tsx
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const badgeVariants = cva(
  "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
  {
    variants: {
      status: {
        pending: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200",
        active: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200",
        inactive: "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200",
        error: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200",
      },
      size: {
        sm: "text-xs px-2 py-0.5",
        md: "text-sm px-2.5 py-0.5",
        lg: "text-base px-3 py-1",
      },
    },
    defaultVariants: {
      status: "pending",
      size: "md",
    },
  }
)

interface StatusBadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export function StatusBadge({ className, status, size, ...props }: StatusBadgeProps) {
  return <span className={cn(badgeVariants({ status, size }), className)} {...props} />
}

// Usage
<StatusBadge status="active">Online</StatusBadge>
<StatusBadge status="error" size="lg">Failed</StatusBadge>
```

## CVA Button with Multiple Variants

```tsx
// components/custom/action-button.tsx
import { cva, type VariantProps } from "class-variance-authority"
import { Slot } from "@radix-ui/react-slot"
import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      intent: {
        primary: "bg-primary text-primary-foreground hover:bg-primary/90",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        danger: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        ghost: "hover:bg-accent hover:text-accent-foreground",
      },
      size: {
        sm: "h-9 px-3 text-sm",
        md: "h-11 px-4 text-sm",
        lg: "h-12 px-6 text-base",
        icon: "h-11 w-11",
      },
      fullWidth: {
        true: "w-full",
        false: "",
      },
    },
    defaultVariants: {
      intent: "primary",
      size: "md",
      fullWidth: false,
    },
  }
)

interface ActionButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

export function ActionButton({
  className,
  intent,
  size,
  fullWidth,
  asChild = false,
  ...props
}: ActionButtonProps) {
  const Comp = asChild ? Slot : "button"
  return <Comp className={cn(buttonVariants({ intent, size, fullWidth }), className)} {...props} />
}

// Usage
<ActionButton intent="primary" size="lg">Save</ActionButton>
<ActionButton intent="danger" size="sm">Delete</ActionButton>
<ActionButton intent="ghost" size="icon"><TrashIcon /></ActionButton>
<ActionButton fullWidth>Full Width</ActionButton>
```

## Compound Component Pattern

Related components that share state via Context:

```tsx
// components/custom/stat-card.tsx
import { createContext, useContext } from "react"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { cn } from "@/lib/utils"

const StatCardContext = createContext<{ trend?: "up" | "down" | "neutral" }>({})

function StatCard({ children, className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <Card className={cn("", className)} {...props}>
      {children}
    </Card>
  )
}

function StatCardHeader({ children, trend }: { children: React.ReactNode; trend?: "up" | "down" | "neutral" }) {
  return (
    <StatCardContext.Provider value={{ trend }}>
      <CardHeader className="pb-2">{children}</CardHeader>
    </StatCardContext.Provider>
  )
}

function StatCardTitle({ children }: { children: React.ReactNode }) {
  return <p className="text-sm font-medium text-muted-foreground">{children}</p>
}

function StatCardValue({ children }: { children: React.ReactNode }) {
  const { trend } = useContext(StatCardContext)
  return (
    <p className={cn(
      "text-2xl font-bold",
      trend === "up" && "text-green-600",
      trend === "down" && "text-red-600"
    )}>
      {children}
    </p>
  )
}

function StatCardContent({ children }: { children: React.ReactNode }) {
  return <CardContent className="pt-0">{children}</CardContent>
}

// Attach subcomponents
StatCard.Header = StatCardHeader
StatCard.Title = StatCardTitle
StatCard.Value = StatCardValue
StatCard.Content = StatCardContent

export { StatCard }

// Usage
<StatCard>
  <StatCard.Header trend="up">
    <StatCard.Title>Revenue</StatCard.Title>
    <StatCard.Value>$45,231</StatCard.Value>
  </StatCard.Header>
  <StatCard.Content>
    <p className="text-xs text-muted-foreground">+20.1% from last month</p>
  </StatCard.Content>
</StatCard>
```

## Polymorphic Component with asChild

Render as different elements using Radix Slot:

```tsx
// components/custom/text.tsx
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const textVariants = cva("", {
  variants: {
    variant: {
      h1: "text-4xl font-bold tracking-tight",
      h2: "text-3xl font-semibold tracking-tight",
      h3: "text-2xl font-semibold",
      body: "text-base",
      small: "text-sm text-muted-foreground",
      muted: "text-sm text-muted-foreground",
    },
  },
  defaultVariants: {
    variant: "body",
  },
})

interface TextProps
  extends React.HTMLAttributes<HTMLParagraphElement>,
    VariantProps<typeof textVariants> {
  asChild?: boolean
}

export function Text({ className, variant, asChild = false, ...props }: TextProps) {
  const Comp = asChild ? Slot : "p"
  return <Comp className={cn(textVariants({ variant }), className)} {...props} />
}

// Usage - renders as <p>
<Text variant="body">Regular paragraph</Text>

// Usage - renders as <h1> with Text styles
<Text variant="h1" asChild>
  <h1>Page Title</h1>
</Text>

// Usage - renders as <span>
<Text variant="small" asChild>
  <span>Inline text</span>
</Text>
```

## Form Field Wrapper

Combine Label + Input + Error into single component:

```tsx
// components/custom/form-input.tsx
import { Input, type InputProps } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { cn } from "@/lib/utils"
import { forwardRef } from "react"

interface FormInputProps extends InputProps {
  label: string
  error?: string
  description?: string
}

export const FormInput = forwardRef<HTMLInputElement, FormInputProps>(
  ({ label, error, description, className, id, ...props }, ref) => {
    const inputId = id || label.toLowerCase().replace(/\s+/g, "-")

    return (
      <div className="space-y-1.5">
        <Label htmlFor={inputId} className={error ? "text-destructive" : ""}>
          {label}
        </Label>
        <Input
          ref={ref}
          id={inputId}
          className={cn("h-11", error && "border-destructive", className)}
          aria-invalid={!!error}
          aria-describedby={error ? `${inputId}-error` : undefined}
          {...props}
        />
        {description && !error && (
          <p className="text-sm text-muted-foreground">{description}</p>
        )}
        {error && (
          <p id={`${inputId}-error`} className="text-sm text-destructive">
            {error}
          </p>
        )}
      </div>
    )
  }
)
FormInput.displayName = "FormInput"

// Usage
<FormInput
  label="Email"
  type="email"
  placeholder="you@example.com"
  error={errors.email?.message}
/>
```

## Responsive Dialog/Drawer

Bottom sheet on mobile, modal on desktop:

```tsx
// components/custom/responsive-modal.tsx
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog"
import { Drawer, DrawerContent, DrawerHeader, DrawerTitle, DrawerDescription } from "@/components/ui/drawer"
import { useMediaQuery } from "@/hooks/use-media-query"

interface ResponsiveModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description?: string
  children: React.ReactNode
}

export function ResponsiveModal({
  open,
  onOpenChange,
  title,
  description,
  children,
}: ResponsiveModalProps) {
  const isDesktop = useMediaQuery("(min-width: 768px)")

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>{title}</DialogTitle>
            {description && <DialogDescription>{description}</DialogDescription>}
          </DialogHeader>
          {children}
        </DialogContent>
      </Dialog>
    )
  }

  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent>
        <DrawerHeader>
          <DrawerTitle>{title}</DrawerTitle>
          {description && <DrawerDescription>{description}</DrawerDescription>}
        </DrawerHeader>
        <div className="px-4 pb-4">{children}</div>
      </DrawerContent>
    </Drawer>
  )
}
```

## Confirmation Dialog

Reusable confirmation pattern:

```tsx
// components/custom/confirm-dialog.tsx
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"

interface ConfirmDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description: string
  confirmText?: string
  cancelText?: string
  variant?: "default" | "destructive"
  onConfirm: () => void
}

export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmText = "Continue",
  cancelText = "Cancel",
  variant = "default",
  onConfirm,
}: ConfirmDialogProps) {
  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{cancelText}</AlertDialogCancel>
          <AlertDialogAction
            onClick={onConfirm}
            className={variant === "destructive" ? "bg-destructive text-destructive-foreground hover:bg-destructive/90" : ""}
          >
            {confirmText}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}

// Usage
<ConfirmDialog
  open={showDelete}
  onOpenChange={setShowDelete}
  title="Delete item?"
  description="This action cannot be undone."
  confirmText="Delete"
  variant="destructive"
  onConfirm={handleDelete}
/>
```
