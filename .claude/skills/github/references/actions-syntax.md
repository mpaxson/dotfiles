# GitHub Actions Workflow Syntax

Complete reference for workflow YAML configuration.

## Triggers (on)

### Push/Pull Request

```yaml
on:
  push:
    branches: [main, 'release/*']
    branches-ignore: ['feature/*']
    tags: ['v*']
    paths: ['src/**', '*.json']
    paths-ignore: ['**.md', 'docs/**']

  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    branches: [main]
    paths: ['src/**']

  pull_request_target:        # Runs in base branch context (security!)
    types: [opened]
```

### Scheduled/Manual

```yaml
on:
  schedule:
    - cron: '0 2 * * *'       # Daily at 2am UTC
    - cron: '*/15 * * * *'    # Every 15 minutes

  workflow_dispatch:          # Manual trigger
    inputs:
      environment:
        type: choice
        options: [dev, staging, prod]
        default: dev
      debug:
        type: boolean
        default: false
```

### Other Events

```yaml
on:
  release:
    types: [published, created]

  workflow_call:              # Reusable workflow
    inputs:
      config:
        type: string
        required: true
    secrets:
      token:
        required: true
    outputs:
      result:
        value: ${{ jobs.build.outputs.result }}

  repository_dispatch:        # External trigger
    types: [deploy]

  issue_comment:
    types: [created]
```

## Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true    # Cancel older runs

# Per-environment concurrency
concurrency:
  group: deploy-${{ github.event.inputs.environment }}
  cancel-in-progress: false   # Queue deploys
```

## Jobs

### Basic Structure

```yaml
jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest
    timeout-minutes: 15

    permissions:
      contents: read
      packages: write

    environment:
      name: production
      url: https://example.com

    defaults:
      run:
        working-directory: ./app
        shell: bash

    env:
      NODE_ENV: production
```

### Runners

```yaml
runs-on: ubuntu-latest        # GitHub-hosted
runs-on: ubuntu-22.04         # Specific version
runs-on: macos-latest         # macOS (10x cost)
runs-on: windows-latest       # Windows (2x cost)
runs-on: [self-hosted, linux] # Self-hosted with labels
runs-on:
  group: my-runner-group      # Runner group
  labels: [linux, x64]
```

### Dependencies

```yaml
jobs:
  build:
    # ...
  test:
    needs: build
  deploy:
    needs: [build, test]
    if: success()             # Only if all passed
```

### Matrix

```yaml
strategy:
  fail-fast: false            # Don't cancel on failure
  max-parallel: 4             # Limit concurrent jobs
  matrix:
    os: [ubuntu-latest, macos-latest]
    node: [18, 20, 22]
    include:
      - os: ubuntu-latest
        node: 22
        coverage: true        # Add property to specific combo
    exclude:
      - os: macos-latest
        node: 18              # Skip this combination
```

### Outputs

```yaml
jobs:
  build:
    outputs:
      version: ${{ steps.version.outputs.value }}
    steps:
      - id: version
        run: echo "value=1.0.0" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.version }}"
```

## Steps

### Actions

```yaml
steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0          # Full history
      submodules: recursive

  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
      registry-url: 'https://npm.pkg.github.com'

  - uses: ./.github/actions/custom  # Local action

  - uses: owner/repo/path@v1        # Subdirectory action
```

### Run Commands

```yaml
steps:
  - run: npm test

  - run: |
      npm ci
      npm run build

  - name: Multi-line with env
    run: |
      echo "Building $VERSION"
      ./build.sh
    env:
      VERSION: ${{ github.sha }}
    shell: bash
    working-directory: ./app
    continue-on-error: true
```

### Conditionals

```yaml
steps:
  - if: github.event_name == 'push'
    run: echo "Push event"

  - if: github.ref == 'refs/heads/main'
    run: echo "Main branch"

  - if: contains(github.event.head_commit.message, '[deploy]')
    run: ./deploy.sh

  - if: always()              # Run even if previous failed
    run: ./cleanup.sh

  - if: failure()             # Only on failure
    run: ./notify-failure.sh

  - if: cancelled()           # Only if cancelled
    run: echo "Workflow cancelled"
```

## Contexts

```yaml
# github context
${{ github.actor }}           # User who triggered
${{ github.repository }}      # owner/repo
${{ github.ref }}             # refs/heads/main
${{ github.sha }}             # Commit SHA
${{ github.event_name }}      # push, pull_request, etc
${{ github.run_id }}          # Unique run ID
${{ github.run_number }}      # Run counter
${{ github.workflow }}        # Workflow name

# env context
${{ env.MY_VAR }}

# secrets context
${{ secrets.GITHUB_TOKEN }}
${{ secrets.MY_SECRET }}

# job context
${{ job.status }}

# steps context
${{ steps.step-id.outputs.value }}
${{ steps.step-id.outcome }}  # success, failure, cancelled, skipped

# matrix context
${{ matrix.os }}
${{ matrix.node }}

# needs context
${{ needs.job-id.outputs.value }}
${{ needs.job-id.result }}    # success, failure, cancelled, skipped
```

## Expressions

```yaml
# String functions
${{ contains(github.event.head_commit.message, '[skip ci]') }}
${{ startsWith(github.ref, 'refs/tags/') }}
${{ endsWith(github.repository, '-demo') }}
${{ format('Hello {0}!', github.actor) }}
${{ join(matrix.os, ', ') }}
${{ toJSON(github.event) }}
${{ fromJSON(steps.data.outputs.json) }}

# Logical
${{ github.ref == 'refs/heads/main' && github.event_name == 'push' }}
${{ github.event_name == 'pull_request' || github.event_name == 'push' }}
${{ !cancelled() }}

# Status checks
${{ success() }}              # All previous succeeded
${{ failure() }}              # Any previous failed
${{ always() }}               # Always run
${{ cancelled() }}            # Workflow cancelled

# Hashfiles (for cache keys)
${{ hashFiles('**/package-lock.json') }}
${{ hashFiles('**/*.go', 'go.sum') }}
```

## Environment & Secrets

```yaml
env:
  GLOBAL_VAR: value           # Workflow level

jobs:
  build:
    env:
      JOB_VAR: value          # Job level
    steps:
      - env:
          STEP_VAR: value     # Step level
        run: echo $STEP_VAR

# Dynamic env
steps:
  - run: echo "VERSION=1.0.0" >> $GITHUB_ENV
  - run: echo "Version is $VERSION"

# Secrets
steps:
  - run: echo "${{ secrets.API_KEY }}"
    env:
      API_KEY: ${{ secrets.API_KEY }}

# Environment protection
jobs:
  deploy:
    environment:
      name: production
      url: https://example.com
```

## Artifacts & Caching

```yaml
# Upload artifact
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: |
      dist/
      !dist/**/*.map
    retention-days: 5

# Download artifact
- uses: actions/download-artifact@v4
  with:
    name: build-output
    path: ./dist

# Cache
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-npm-
```

## Services (Containers)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports:
          - 6379:6379
```

## Container Jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: node:20
      env:
        NODE_ENV: test
      volumes:
        - /data:/data
      options: --cpus 2
```
