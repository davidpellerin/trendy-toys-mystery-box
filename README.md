# Trendy Toys Mystery Box — landing page

A single-page site for the Trendy Toys Canada monthly fidget/sensory mystery box.
Plain HTML, CSS, and JavaScript — no build step, no dependencies, no framework.

```
index.html      all sections, plus the inline SVG sprite of toy illustrations
css/styles.css  design tokens + every component
js/main.js      interactions (STRIPE_LINKS config lives at the top)
fonts/          self-hosted Baloo 2 + Nunito (SIL OFL, see fonts/LICENSE.txt)
Makefile        local dev conveniences
```

## Run it locally

```sh
make serve          # http://127.0.0.1:8000
make serve PORT=9000
```

Run `make` on its own to list the available targets:

| Target | What it does |
|--------|--------------|
| `serve` | Serves the site locally |
| `open` | Opens it in your browser |
| `stop` | Kills a stray server left on the port |
| `check` | Checks JS syntax and that every `#anchor` resolves |

Opening `index.html` directly from disk also works — there's no build step.

## Deploy

It's static — any host works: Netlify, Cloudflare Pages, GitHub Pages, S3, or a
plain nginx directory. Upload `index.html` along with the `css/`, `js/`, and
`fonts/` folders and you're done. The fonts are not optional: without them the
page falls back to a system sans and loses most of its character.

## Structure

The page follows a standard subscription-box funnel:

| # | Section | Notes |
|---|---------|-------|
| 1 | Promo bar | Dismissal remembered in `localStorage` |
| 2 | Sticky nav | Hamburger below 860px |
| 3 | Hero | Dual CTA + the open-box illustration |
| 4 | "What could be in your box?" | Scroll-snap carousel of nine illustrated toys |
| 5 | How it works | Three steps |
| 6 | What's inside | Four product categories |
| 7 | Founder note | **Placeholder — see below** |
| 8 | Pricing | Three plans, USD |
| 9 | FAQ | `<details>` accordion |
| 10 | Newsletter | Validation only until an endpoint is set |
| 11 | Social grid | Placeholder tiles |
| 12 | Footer | |
| 13 | Floating mobile CTA | Appears past the hero |

Press and testimonial blocks are built and styled but shipped commented out —
see the note in `index.html` before enabling either.

## Wiring up checkout

Create one [Stripe Payment Link](https://dashboard.stripe.com/payment-links) per
plan, then paste the URLs into the config block at the top of `js/main.js`:

```js
var STRIPE_LINKS = {
  monthly:   'https://buy.stripe.com/...',
  quarterly: 'https://buy.stripe.com/...',
  annual:    'https://buy.stripe.com/...',
  gift:      'https://buy.stripe.com/...'
};
```

Every button carrying `data-stripe="<key>"` picks up the matching URL on load.
Any key left blank falls back to the Etsy shop, so no button ever dead-ends —
including with JavaScript disabled, since the fallback is also hardcoded in each
`href` in the HTML.

Set the Payment Links to **recurring** prices for the three subscription plans
and a **one-time** price for the gift option, and make the amounts match the
prices printed on the pricing cards.

## Launch checklist

**Blocking — the site shouldn't go live without these**

- [ ] **Repoint the domain.** `trendytoys.ca` currently 302-redirects to Etsy.
      That redirect has to be replaced with this site at your DNS/host, otherwise
      nobody will ever see this page. (Consider keeping `/shop` or similar
      pointing at Etsy.)
- [ ] Create the four Stripe Payment Links and fill in `STRIPE_LINKS`.
- [ ] Set real prices in the pricing cards (`index.html`, `#pricing`) and in the
      `Product` JSON-LD in `<head>`.
- [ ] Replace the founder section (`#about`) with your real name, bio, and photo.
      **Do not add therapy, occupational-therapy, or clinical credentials** unless
      you actually hold them.
- [ ] Write Terms & Conditions, Privacy Policy, and Shipping & Returns pages, and
      link them from the footer (currently `#`).
- [ ] Confirm the small-parts / age-suitability wording in the FAQ matches the
      labelling on the products you source.
- [ ] Set the real contact email (currently `hello@trendytoys.ca`, in the footer
      and the JSON-LD).

**Content**

- [ ] Decide whether to keep the illustrations or move to photography. Every
      toy is a `div.toy` holding an `<svg><use href="#toy-…"></svg>`; to use a
      photo instead, swap the whole `div` for an `<img>` carrying the same
      `toy` / `toy--wide` / `tile-*` classes. The illustrations are honest as
      long as the categories match what you actually pack — the carousel says
      so explicitly ("Illustrated here, packed for real").
- [ ] Add `img/og-image.jpg` at 1200×630 for social sharing previews.
- [ ] Fill in the real product names and counts in "What's inside" and the
      carousel captions (marked `TODO` in the HTML).
- [ ] Add a founder photo, or keep the illustrated stand-in (`#toy-avatar`).
- [ ] Add your real Instagram and TikTok URLs (social section and footer).
- [ ] Confirm shipping carrier and delivery timelines in the FAQ.
- [ ] Point the newsletter form's `action` at your email provider (Mailchimp,
      Buttondown, Kit, …). Until then it validates and shows a success message
      but stores nothing.

**Deliberately disabled**

The "As seen in" press strip and the testimonials block are built and styled but
shipped commented out in `index.html`. Enable them **only** with genuine material —
real press placements you can link to, and real customer quotes (your Etsy reviews
are a good source, attributed honestly). Publishing invented press logos or
fabricated testimonials is deceptive advertising and, in Canada, can run afoul of
the Competition Act. Delete the blocks if you don't intend to use them.

## Theming

All colours, type sizes, spacing, and radii are custom properties in the `:root`
block at the top of `css/styles.css`. Changing the palette is a handful of lines.

The design language is "sticker book": every card is a bright shape with a thick
ink outline (`--border-w`) and a hard offset shadow (`--sticker`), buttons sit on
a shadow they can be pressed into (`--press`), and a few elements are set very
slightly askew on purpose. Tile background colours come from the `.tile-pink`,
`.tile-sky`, `.tile-lime`, `.tile-sun`, `.tile-violet` and `.tile-tang` classes,
rotated so neighbouring cards never match.

Each hue is defined in four roles — `--c-x` (dark enough for white text),
`--c-x-bright` (decorative fills only), `--c-x-dark` (text on light) and
`--c-x-soft` (tinted backgrounds). Keep to those roles and contrast stays at
WCAG AA; putting small white text on a `-bright` value will not.

### Illustrations

The toy artwork is a hand-built inline SVG sprite at the top of `<body>`, drawn
once and referenced by id, so the same toy can appear in the carousel, the
category grid and the hero without repeating a path. House style for adding
more is documented in the comment above the sprite.

## Notes

- No external requests: self-hosted fonts, inline SVG artwork, no CDN, no
  trackers. Add analytics deliberately if you want it (and mention it in your
  privacy policy).
- Baloo 2 and Nunito are both variable fonts, so one file per subset covers
  every weight. Only the latin and latin-ext subsets are shipped.
- Everything degrades without JavaScript — nav, FAQ, carousel scrolling, and all
  buy buttons still work.
- Respects `prefers-reduced-motion`.
