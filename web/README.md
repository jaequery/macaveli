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

- `app/page.tsx` — the landing page (Hero / Features / Hotkeys / Footer).
- `app/layout.tsx` — root layout + `<head>` metadata.
- `app/globals.css` — Tailwind v4 entry + design tokens in `@theme`.
- `postcss.config.mjs` — wires `@tailwindcss/postcss`.
