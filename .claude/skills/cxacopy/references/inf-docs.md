# Updating inf-docs (graynet + darknet)

inf-docs builds **two** sites from one `docs/` tree: **graynet** (full) and **darknet**
(consume-only). zensical has no `INHERIT`, so configs are merged at build time and the
darknet output is pruned by page tags.

## Architecture
- `base.toml` — shared config (theme, extensions, css/js). No `nav`.
- `graynet.toml` / `darknet.toml` — inherit base, add their own `nav` (darknet also sets
  `docs_dir = "docs-darknet"`, `site_dir = "site-darknet"`).
- `scripts/render_config.py base.toml <aud>.toml .cfg-<aud>.toml` — deep-merge.
- `scripts/prune_audience.py <site> <aud> [docs_dir]` — after build, drop pages whose
  tags exclude `<aud>` and scrub `search.json` + delete `objects.inv` (no graynet text
  leaks into the darknet build).
- `scripts/vendor_assets.py <site>` — Docker build only; vendors fonts + mermaid/glightbox
  for airgap (root-absolute `/assets/vendor/...`).

## Tags (the audience switch)
Every page's front matter carries `tags:`:
- `graynet` — graynet-only (gitlab, guides, network, systems, services, `index.md`).
- `darknet` — darknet-only (`darknet-home.md`).
- both — shared (everything under `cxacopy/`).
- untagged ⇒ kept in both builds (avoid; tag explicitly).

A page is kept in `<aud>` if untagged OR tagged `<aud>`; otherwise pruned. The **darknet
home** is `docs/darknet-home.md` (tag `darknet`) — `build-darknet` stages `docs-darknet/`
and renames it to `index.md` so it becomes the root.

## Common edits
1. **New page:** create `docs/<section>/<page>.md` with front matter:
   ```yaml
   ---
   icon: material/<icon>
   tags: [graynet]          # or [graynet, darknet]
   ---
   ```
2. **Nav:** add the path to `graynet.toml` and/or `darknet.toml` `nav` (darknet nav =
   Home + CXACopy only). A graynet-only page goes in `graynet.toml` solely.
3. **Tab icon:** masked in `docs/stylesheets/extra.css` keyed by href (`/<section>/`);
   add an SVG to `docs/assets/icons/` + a `--tab-icon` rule if it's a new top tab.
4. **Snippets/cards:** reusable cards live in `docs/_includes/cards/` (`--8<--` include).
   Changing them needs `--clean` (incremental build won't pick them up).

## Build & preview
```bash
just docs::build           # graynet → site/   (renders + --clean + prune)
just docs::build-darknet   # darknet → site-darknet/   (stages docs-darknet, prunes)
just docs::live            # preview graynet  :8000
just docs::live-darknet    # preview darknet  :8001
```

## Verify (run before committing)
```bash
just docs::lint            # pymarkdown (front-matter aware) + codespell — must pass
just docs::build && just docs::build-darknet      # both must say "No issues found"

# a graynet-only page is in graynet, absent from darknet:
test -e site/<section>/<page>/index.html && echo graynet-ok
test ! -e site-darknet/<section>/<page> && echo darknet-excluded-ok

# no graynet text leaked into the darknet search index:
grep -ciE 'gitlab-runner|static ip|subnet' site-darknet/search.json   # want 0
```
CI mirrors of this: `docs-lint`, `docs-build`, `pages` (graynet → Pages),
`docs-publish-help` (darknet → copyparty `/help`), `docs-release-image` +
`docs-publish-skill` on tags.

## Gotchas
- zensical **skips dot-prefixed dirs** — the darknet staging dir is `docs-darknet/` (no dot).
- graynet + darknet share `.cache`; both builds use `--clean` or the 2nd no-ops.
- After editing `_includes/`, always `--clean`.
