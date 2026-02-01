# GitHub Actions Optimization

Advanced patterns for faster builds and reduced costs.

## Cost Comparison

| Runner | Multiplier | Use When |
|--------|------------|----------|
| ubuntu-latest | 1x | Default choice |
| windows-latest | 2x | Windows-only builds |
| macos-latest | 10x | iOS/macOS only |
| self-hosted | 0x | High volume, special hardware |

## Caching Strategies

### Dependency Caching

```yaml
# Built-in (preferred for supported ecosystems)
- uses: actions/setup-node@v4
  with:
    cache: 'npm'              # Also: yarn, pnpm

- uses: actions/setup-python@v5
  with:
    cache: 'pip'              # Also: poetry, pipenv

- uses: actions/setup-go@v5
  with:
    cache: true               # Caches go modules

# Manual cache (for custom paths)
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache/pip
      ~/.local/share/virtualenvs
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-
```

### Build Cache

```yaml
# Turborepo / Nx cache
- uses: actions/cache@v4
  with:
    path: .turbo
    key: ${{ runner.os }}-turbo-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-turbo-

# Gradle cache
- uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}

# Rust cache
- uses: Swatinem/rust-cache@v2
```

### Docker Layer Caching

```yaml
# BuildKit cache mount (best)
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max

# Registry cache
- uses: docker/build-push-action@v5
  with:
    cache-from: type=registry,ref=user/app:cache
    cache-to: type=registry,ref=user/app:cache,mode=max
```

## Parallelization

### Matrix Strategies

```yaml
# Basic matrix
strategy:
  fail-fast: false            # Don't cancel siblings
  matrix:
    os: [ubuntu-latest, macos-latest]
    version: [18, 20, 22]

# Sharding tests
strategy:
  matrix:
    shard: [1, 2, 3, 4]
steps:
  - run: npm test -- --shard=${{ matrix.shard }}/4

# Dynamic matrix from JSON
jobs:
  setup:
    outputs:
      matrix: ${{ steps.set.outputs.matrix }}
    steps:
      - id: set
        run: echo "matrix=$(jq -c . matrix.json)" >> $GITHUB_OUTPUT

  build:
    needs: setup
    strategy:
      matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}
```

### Parallel Jobs

```yaml
jobs:
  lint:                       # These run in parallel
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint

  typecheck:                  # Parallel with lint
    runs-on: ubuntu-latest
    steps:
      - run: npm run typecheck

  test:                       # Parallel with lint & typecheck
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  build:
    needs: [lint, typecheck, test]  # Waits for all
    runs-on: ubuntu-latest
    steps:
      - run: npm run build
```

### Artifact Passing

```yaml
jobs:
  build:
    steps:
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
          retention-days: 1

  test-e2e:
    needs: build
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
      - run: npm run test:e2e
```

## Early Termination

### Path Filters

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'package.json'
      - '.github/workflows/**'
    paths-ignore:
      - '**.md'
      - 'docs/**'
      - '.vscode/**'
```

### Conditional Jobs

```yaml
jobs:
  changes:
    outputs:
      backend: ${{ steps.filter.outputs.backend }}
      frontend: ${{ steps.filter.outputs.frontend }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            backend:
              - 'api/**'
            frontend:
              - 'web/**'

  backend-tests:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    # ...

  frontend-tests:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    # ...
```

### Skip Conditions

```yaml
jobs:
  build:
    # Skip for docs-only, drafts, or [skip ci]
    if: |
      !contains(github.event.head_commit.message, '[skip ci]') &&
      !github.event.pull_request.draft &&
      (
        github.event_name != 'pull_request' ||
        !contains(github.event.pull_request.labels.*.name, 'documentation')
      )
```

## Checkout Optimization

```yaml
# Shallow clone (fastest)
- uses: actions/checkout@v4
  with:
    fetch-depth: 1

# Sparse checkout (for monorepos)
- uses: actions/checkout@v4
  with:
    sparse-checkout: |
      packages/my-app
      shared/

# No checkout (for API-only jobs)
jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - run: curl -X POST $WEBHOOK_URL
        env:
          WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## Self-Hosted Runner Optimization

### Runner Setup

```yaml
runs-on: [self-hosted, linux, x64]

# With container
container:
  image: node:20
  options: --cpus 4 --memory 8g
```

### Persistent Cache

```bash
# Pre-install common dependencies on runner
npm install -g typescript eslint prettier

# Pre-pull Docker images
docker pull node:20
docker pull postgres:15
```

### Cleanup

```yaml
# Add cleanup step
- name: Cleanup
  if: always()
  run: |
    docker system prune -f
    rm -rf node_modules dist
```

## Workflow Optimization Checklist

### Before Running
- [ ] Use `paths` filter to skip irrelevant changes
- [ ] Add `concurrency` to cancel stale runs
- [ ] Set `timeout-minutes` on all jobs

### Caching
- [ ] Use setup-action's built-in cache
- [ ] Cache build outputs (Turbo, Nx, Gradle)
- [ ] Use Docker BuildKit GHA cache

### Parallelization
- [ ] Run independent jobs in parallel
- [ ] Use matrix for multi-version testing
- [ ] Shard large test suites

### Cost Reduction
- [ ] Use ubuntu-latest when possible
- [ ] Shallow checkout with `fetch-depth: 1`
- [ ] Consider self-hosted for high volume
- [ ] Use `if: failure()` for cleanup instead of `always()`

## Example: Optimized CI Pipeline

```yaml
name: CI
on:
  push:
    branches: [main]
    paths-ignore: ['**.md']
  pull_request:
    paths-ignore: ['**.md']

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      src: ${{ steps.filter.outputs.src }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            src:
              - 'src/**'
              - 'package*.json'

  lint-and-type:
    needs: changes
    if: needs.changes.outputs.src == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint & npm run typecheck & wait

  test:
    needs: changes
    if: needs.changes.outputs.src == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    strategy:
      fail-fast: false
      matrix:
        shard: [1, 2, 3]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --shard=${{ matrix.shard }}/3

  build:
    needs: [lint-and-type, test]
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - uses: actions/cache@v4
        with:
          path: .next/cache
          key: ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-${{ hashFiles('src/**') }}
          restore-keys: |
            ${{ runner.os }}-nextjs-${{ hashFiles('**/package-lock.json') }}-
      - run: npm ci
      - run: npm run build
```
