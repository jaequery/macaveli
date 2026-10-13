# Macaveli — web

Marketing landing page for the Macaveli macOS app. Next.js 15 (App Router) +
TypeScript + Tailwind v4.

## Develop

```sh
cd web
npm install
npm run dev
```

Open http://localhost:3000.

## Build

```sh
npm run build
npm run start
```

## Deploy

Static-ish app — works on Vercel, Cloudflare Pages, Netlify, or any Node host.
For Vercel: `vercel deploy` from this folder.

## Files

- `app/page.tsx` — the landing page ("Bento Tactile"; see `/DESIGN.md`).
- `app/changelog/` — the changelog page + its release data.
- `app/components/site.tsx` — shared Nav, Footer, keycaps and links (reads `version.json`).
- `app/components/site-effects.tsx` — the only client JS: scroll reveal, nav hairline, hero keycaps.
- `app/layout.tsx` — root layout + `<head>` metadata.
- `app/globals.css` — design tokens (light + dark) and all site styles.
- `postcss.config.mjs` — wires `@tailwindcss/postcss`.
