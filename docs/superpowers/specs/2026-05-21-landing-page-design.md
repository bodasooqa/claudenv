# claudenv landing page — design

**Date:** 2026-05-21
**Status:** Approved (pending implementation plan)

## Goal

Ship a one-page marketing/install landing for [claudenv](https://github.com/bodasooqa/claudenv), hosted on GitHub Pages at `https://bodasooqa.github.io/claudenv/`. The page sells the tool in one screen, demonstrates the core flow via an animated terminal, and funnels users to the install command and the GitHub repo.

This is **not** a replacement for the README. The README stays canonical; the landing is a friendlier first-touch surface.

## Non-goals

- Full documentation site (commands cheatsheet, how-it-works deep dive, multi-page docs).
- Comparison table with competitors — already in README.
- Dark/light theme toggle (page is dark-only by design — it's a shell tool).
- Multi-language.
- Analytics, service worker, PWA features.
- Build pipeline / framework / SSG.

## Hosting

- **Source = published.** Files live in `/docs` on the `main` branch.
- GitHub Pages settings: *Deploy from a branch → `main` → `/docs`*.
- URL: `https://bodasooqa.github.io/claudenv/`.
- No GitHub Actions deploy job required.
- Custom domain: not in scope.

## Tech stack

- Plain HTML, CSS, vanilla JS.
- One external dependency: **JetBrains Mono** via Google Fonts (subset Latin).
- No bundler, no framework, no Node toolchain.
- Target bundle: under 20kb total (excl. font), single critical-path render.

## File layout

```
docs/
├── index.html       # semantic markup, all content
├── style.css        # CSS variables + grid + responsive
├── app.js           # copy-to-clipboard + terminal animation
└── favicon.svg      # terminal-glyph favicon
```

## Page structure (top → bottom)

### 1. Hero

- Wordmark `claudenv` in JetBrains Mono, large weight.
- Tagline (one line): *"nvm-style account manager for Claude Code."*
- Sub-tagline (one line, dimmer): *"Set a default account, override per-project, optionally auto-switch on `cd`. Zero dependencies."*
- Install command in a fake-terminal block:
  ```
  $ curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh | bash
  ```
  with a "Copy" button on the right edge. Button shows "Copied!" for 1.5s on success.
- Status badges row (same as README): ShellCheck CI, MIT license, macOS, Linux.
- Two CTAs:
  - Primary: **View on GitHub** → `https://github.com/bodasooqa/claudenv` (accent-orange button).
  - Secondary: **See it in action** → anchor link to terminal demo section.

### 2. Animated terminal demo

A faux macOS-style terminal window (three traffic-light circles in the top-left for atmosphere; not interactive).

Animated typing sequence, looped:

```
$ claudenv import default
✓ imported ~/.claude as 'default'
$ claudenv add work
✓ created account 'work'
$ claudenv use work
switched to: work
$ claude
(launches with the 'work' profile)
```

- Typing animation in pure CSS + small JS controller; no GIF, no video.
- Loop interval: ~12-15 seconds, with a ~1.5s pause before restart.
- Honors `prefers-reduced-motion`: shows the final state statically instead of typing.
- A blinking cursor follows the latest typed character.

### 3. Why claudenv (feature cards)

Four cards in a 2×2 grid (collapses to 1 column on mobile, ~640px breakpoint).

| Card | Body (≤15 words) |
|------|------|
| **Zero dependencies** | Pure shell. No Node, Ruby, Python. Just `bash`/`zsh` and `claude`. |
| **Per-project pinning** | `.claudenvrc` walks up from `$PWD` like `.nvmrc`. Commit it for the team. |
| **Auto-switch on `cd`** | Opt-in shell hook switches profiles when you enter a project folder. |
| **No file patching** | Uses the official `CLAUDE_CONFIG_DIR` env var. Your `~/.claude` stays untouched. |

Each card: small monospace icon/glyph at top-left (e.g. `[01]`, `[02]`, `[03]`, `[04]` in dim accent), title, body.

### 4. Footer

- Left: link to GitHub repo.
- Center: MIT license link → `LICENSE` file on GitHub.
- Right: *"Not affiliated with Anthropic."* in dim gray.

Below: small line *"Built by [@bodasooqa](https://github.com/bodasooqa)"*.

## Visual language

### Colors

CSS variables on `:root`:

| Token | Value | Use |
|---|---|---|
| `--bg` | `#0a0a0a` | Page background |
| `--bg-elev` | `#161616` | Terminal windows, cards |
| `--fg` | `#e5e5e5` | Primary text |
| `--fg-dim` | `#8a8a8a` | Secondary text, prompts |
| `--accent` | `#ff7a59` | CTA, headings highlight, links |
| `--accent-dim` | `#a04733` | Hover/pressed states |
| `--success` | `#5fff7f` | `✓` glyphs in terminal demo |
| `--border` | `#262626` | Card outlines, dividers |

### Typography

- **All text:** `JetBrains Mono`, loaded via Google Fonts with `display=swap`.
- Weights used: 400 (body), 500 (subheads), 700 (hero wordmark).
- Sizes (mobile-first, clamp-based for fluid scaling):
  - Hero wordmark: `clamp(2.5rem, 8vw, 5rem)`
  - Tagline: `clamp(1.1rem, 2.5vw, 1.5rem)`
  - Body: `1rem` (16px base)
  - Small (badges, footer): `0.85rem`
- Line height: 1.5 for body, 1.2 for headings.

### Layout

- Single column, max-width `~720px` for text, `~960px` for the terminal demo.
- Centered with horizontal padding (`clamp(1rem, 4vw, 2rem)`).
- Generous vertical rhythm between sections (~5rem on desktop, ~3rem on mobile).

### Motion

- Hero install-block has a subtle one-time fade-in on load (~400ms).
- Terminal demo animates per the schedule above.
- CTA button: 150ms color transition on hover.
- All motion gated behind `prefers-reduced-motion: no-preference`.

## Behavior / JS surface

- **Copy-to-clipboard:** click "Copy" on the install block → `navigator.clipboard.writeText(command)` → swap button label to "Copied!" for 1.5s → restore.
- **Terminal animation:** controller iterates through a hard-coded script of `{type: "input" | "output" | "pause", text: string, delayMs: number}` entries, rendering character-by-character for inputs. After the final step, pause 1.5s, then restart.
- **Reduced motion:** if `matchMedia('(prefers-reduced-motion: reduce)').matches`, skip the animation and render the final terminal state statically.

Total JS budget: ≤100 lines, no dependencies.

## Accessibility

- All interactive elements (copy button, CTAs) keyboard-navigable with visible `:focus-visible` outline using `--accent`.
- Copy button has `aria-label="Copy install command"`.
- Terminal demo region marked `aria-hidden="true"` — it's decorative; the install command in hero is the real surface.
- Color contrast: `--fg` on `--bg` ≈ 14:1 (AAA); `--accent` on `--bg` ≈ 6:1 (AA large).
- Page has a single `<h1>` (the wordmark), then `<h2>` per section.

## Responsive breakpoints

- Mobile-first base styles.
- Single breakpoint at `min-width: 640px`:
  - Feature cards switch from 1 column to 2×2 grid.
  - Hero CTAs go side-by-side instead of stacked.
- Terminal demo: scales with viewport width via `max-width: 100%`. Font-size inside the demo also uses `clamp` so it stays readable on small phones (down to ~320px).

## Open questions

None blocking implementation. The following are intentionally deferred:
- Favicon design (placeholder is a simple `>_` glyph in `--accent`).
- Possible OG image / Twitter card meta tags — can be added in a follow-up.

## Out of scope (explicit YAGNI)

- Comparison table with claude-switch (lives in README).
- Commands cheatsheet (lives in README).
- How-it-works section (lives in README).
- Light theme.
- i18n.
- Analytics.
- Sitemap / robots.txt tuning (default GH Pages behavior is fine).
