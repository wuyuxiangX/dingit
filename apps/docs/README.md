# @dingit/docs

The Dingit website — **both** the landing page at `dingit.me` and the
user documentation at `dingit.me/docs`. One Next.js 16 / Fumadocs 16
app serves both surfaces from the same codebase, the same brand theme,
and the same deploy.

> Originally planned as two separate apps (`apps/docs` + `apps/www`),
> merged into one in the WYX-429 landing expansion. The `apps/www` plan
> was cancelled on Linear (WYX-430) — see its comment for context.

## Layout

- **`src/app/[lang]/(home)/`** — the marketing surface (Hero, Field
  Dispatches, Install, Colophon). Uses Fumadocs' `HomeLayout` so it
  renders without the docs sidebar. The page is shaped as a small
  editorial zine about interactive notifications.
- **`src/app/[lang]/docs/`** — the docs surface. Uses `DocsLayout` with
  the sidebar, TOC, and page tree.
- **`src/lib/dict.ts`** — typed bilingual text dictionary for the
  editorial landing (MDX files under `content/docs/` carry their own
  i18n via the `name.zh.mdx` convention).
- **`content/docs/`** — authored Markdown/MDX. English is the default,
  Chinese files co-locate as `name.zh.mdx` and fall back to English
  when missing.
- **`src/lib/source.ts`** — Fumadocs content source adapter.
- **`src/lib/layout.shared.tsx`** — `baseOptions()` shared across both
  HomeLayout and DocsLayout.
- **`proxy.ts`** (at the project root, not under `src/`) — Next 16
  middleware combining Markdown content negotiation + Fumadocs i18n
  locale prefix handling.

## Run

From the **repo root** (always go through the pnpm workspace, never
`cd apps/docs`):

```bash
make docs-dev        # dev server on :3500
make docs-build      # production build
make docs-start      # production server
make docs-clean      # drop .next / .source / node_modules
```

## Brand

Colors, fonts, and tone mirror the Flutter app token-for-token. See
`src/app/global.css` for the mapping back to
`apps/app/lib/app/theme/tokens/app_tokens.dart`. Never invent new
colors in the docs — add them in Dart first, then mirror.

Typography pairs DM Serif Display (editorial headlines, pull quotes,
section numbers) with Plus Jakarta Sans (body). Font-feature settings
force ligatures, kerning, and contextual alternates on in `global.css`
so the display serif renders its intended glyph set.

## References

- [Fumadocs documentation](https://fumadocs.dev)
- [Next.js 16 docs](https://nextjs.org/docs)
- The Dingit server / CLI / App live in sibling `apps/` directories in
  the same monorepo.
