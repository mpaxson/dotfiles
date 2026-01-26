---
paths:
  - "**/justfile"
  - "**/.justfile"
  - "**/Justfile"
  - "**/*.just"
---

# Justfile Development

When working with justfiles, apply the **just** skill.

## Justfile Basics

```just
# Set shell for all recipes
set shell := ["bash", "-uc"]

# Variables
project := "myapp"

# Recipe with dependencies
build: lint test
    @echo "Building {{project}}"

# Recipe with arguments
deploy env="staging":
    ./deploy.sh {{env}}

# Private recipe (prefixed with _)
_setup:
    @echo "Internal setup"
```

## Common Patterns

### Default Recipe
```just
# First recipe is default
default:
    @just --list
```

### Working Directory
```just
# Run in specific directory
[working-directory: "frontend"]
build-frontend:
    npm run build
```

### Conditional Execution
```just
check:
    #!/usr/bin/env bash
    if [[ -f "package.json" ]]; then
        npm test
    fi
```

## Reference

For complete patterns and the `./dev` bootstrap script, invoke the `just` skill.
