# Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a single-page terminal-aesthetic landing for claudenv at `https://bodasooqa.github.io/claudenv/` using plain HTML/CSS/JS in `/docs`, served directly by GitHub Pages.

**Architecture:** Three source files in `/docs` (`index.html`, `style.css`, `app.js`) + favicon. No bundler, no build step. CSS variables drive the design system; vanilla JS handles copy-to-clipboard and the terminal typing animation. GitHub Pages serves files from `main` branch `/docs` folder.

**Tech Stack:** HTML5, CSS3 (custom properties, grid, `clamp()`), vanilla ES6 JS, JetBrains Mono via Google Fonts.

**Verification approach:** This project has no test framework (by design — zero deps). Each task's "verification" step is opening the page locally and visually checking the result. Serve with `python3 -m http.server 8000 -d docs`, then open `http://localhost:8000`.

**Reference:** See [`docs/superpowers/specs/2026-05-21-landing-page-design.md`](../specs/2026-05-21-landing-page-design.md) for the full design.

---

## Task 1: Scaffold /docs and verify local serving

**Files:**
- Create: `docs/index.html`
- Create: `docs/style.css`
- Create: `docs/app.js`

- [ ] **Step 1: Create `docs/index.html` with minimal valid HTML5**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>claudenv — nvm-style account manager for Claude Code</title>
  <meta name="description" content="nvm-style account manager for Claude Code. Set a default, override per-project, optionally auto-switch on cd. Zero dependencies.">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main>
    <h1>claudenv</h1>
    <p>placeholder</p>
  </main>
  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 2: Create `docs/style.css` empty (just a comment)**

```css
/* claudenv landing — styles */
```

- [ ] **Step 3: Create `docs/app.js` empty (just a comment)**

```js
// claudenv landing — interactions
```

- [ ] **Step 4: Start local server and verify**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected: page shows "claudenv" heading and "placeholder" text, no console errors.
Stop the server with Ctrl+C when done.

- [ ] **Step 5: Commit**

```bash
git add docs/index.html docs/style.css docs/app.js
git commit -m "Scaffold landing page in /docs"
```

---

## Task 2: CSS foundation — tokens, font, base styles

**Files:**
- Modify: `docs/index.html` (add font link, semantic structure)
- Modify: `docs/style.css` (variables, reset, base)

- [ ] **Step 1: Add JetBrains Mono preconnect + font link in `<head>`**

In `docs/index.html`, insert these lines right before `<link rel="stylesheet" href="style.css">`:

```html
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap">
```

- [ ] **Step 2: Replace `docs/style.css` with the foundation**

```css
/* claudenv landing — styles */

:root {
  --bg: #0a0a0a;
  --bg-elev: #161616;
  --fg: #e5e5e5;
  --fg-dim: #8a8a8a;
  --accent: #ff7a59;
  --accent-dim: #a04733;
  --success: #5fff7f;
  --border: #262626;

  --font: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  --pad-x: clamp(1rem, 4vw, 2rem);
  --section-gap: clamp(3rem, 8vw, 5rem);
  --content-max: 720px;
  --demo-max: 960px;
}

*, *::before, *::after {
  box-sizing: border-box;
}

html, body {
  margin: 0;
  padding: 0;
}

body {
  background: var(--bg);
  color: var(--fg);
  font-family: var(--font);
  font-size: 16px;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

main {
  max-width: var(--content-max);
  margin: 0 auto;
  padding: var(--section-gap) var(--pad-x);
  display: flex;
  flex-direction: column;
  gap: var(--section-gap);
}

h1, h2, h3 {
  line-height: 1.2;
  margin: 0;
  font-weight: 700;
}

a {
  color: var(--accent);
  text-decoration: none;
}
a:hover { color: var(--accent-dim); }

a:focus-visible,
button:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 3px;
  border-radius: 2px;
}

code, pre {
  font-family: var(--font);
}
```

- [ ] **Step 3: Verify in browser**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected: dark background, light-gray "claudenv" heading rendered in JetBrains Mono. Reload the page — font should load without FOUT after the first visit.

- [ ] **Step 4: Commit**

```bash
git add docs/index.html docs/style.css
git commit -m "Add CSS foundation — tokens, fonts, base styles"
```

---

## Task 3: Write full semantic HTML skeleton (all sections, unstyled)

**Files:**
- Modify: `docs/index.html` (replace `<main>` content with all sections)

- [ ] **Step 1: Replace the `<main>` block in `docs/index.html`**

Replace the entire `<main>...</main>` block with this:

```html
  <main>
    <section class="hero">
      <h1 class="wordmark">claudenv</h1>
      <p class="tagline">nvm-style account manager for <a href="https://docs.claude.com/en/docs/claude-code">Claude Code</a>.</p>
      <p class="subtagline">Set a default account, override per-project, optionally auto-switch on <code>cd</code>. Zero dependencies.</p>

      <div class="install" data-install>
        <pre><code id="install-cmd">curl -fsSL https://raw.githubusercontent.com/bodasooqa/claudenv/main/install.sh | bash</code></pre>
        <button type="button" class="copy" data-copy="#install-cmd" aria-label="Copy install command">Copy</button>
      </div>

      <ul class="badges" aria-label="Project badges">
        <li><a href="https://github.com/bodasooqa/claudenv/actions/workflows/shellcheck.yml"><img src="https://img.shields.io/github/actions/workflow/status/bodasooqa/claudenv/shellcheck.yml?branch=main&label=shellcheck&logo=githubactions&logoColor=white" alt="ShellCheck CI status"></a></li>
        <li><a href="https://github.com/bodasooqa/claudenv/blob/main/LICENSE"><img src="https://img.shields.io/github/license/bodasooqa/claudenv" alt="MIT License"></a></li>
        <li><img src="https://img.shields.io/badge/macOS-supported-000000?logo=apple&logoColor=white" alt="macOS supported"></li>
        <li><img src="https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=black" alt="Linux supported"></li>
      </ul>

      <div class="ctas">
        <a class="btn btn-primary" href="https://github.com/bodasooqa/claudenv">View on GitHub</a>
        <a class="btn btn-secondary" href="#demo">See it in action</a>
      </div>
    </section>

    <section class="demo-section" id="demo" aria-label="Animated terminal demo">
      <div class="terminal" aria-hidden="true">
        <div class="terminal-bar">
          <span class="dot dot-r"></span>
          <span class="dot dot-y"></span>
          <span class="dot dot-g"></span>
        </div>
        <pre class="terminal-body" data-terminal></pre>
      </div>
    </section>

    <section class="features">
      <h2 class="sr-only">Why claudenv</h2>
      <ul class="cards">
        <li class="card">
          <span class="card-num">[01]</span>
          <h3>Zero dependencies</h3>
          <p>Pure shell. No Node, Ruby, Python. Just <code>bash</code>/<code>zsh</code> and <code>claude</code>.</p>
        </li>
        <li class="card">
          <span class="card-num">[02]</span>
          <h3>Per-project pinning</h3>
          <p><code>.claudenvrc</code> walks up from <code>$PWD</code> like <code>.nvmrc</code>. Commit it for the team.</p>
        </li>
        <li class="card">
          <span class="card-num">[03]</span>
          <h3>Auto-switch on <code>cd</code></h3>
          <p>Opt-in shell hook switches profiles when you enter a project folder.</p>
        </li>
        <li class="card">
          <span class="card-num">[04]</span>
          <h3>No file patching</h3>
          <p>Uses the official <code>CLAUDE_CONFIG_DIR</code> env var. Your <code>~/.claude</code> stays untouched.</p>
        </li>
      </ul>
    </section>

    <footer class="footer">
      <div class="footer-row">
        <a href="https://github.com/bodasooqa/claudenv">GitHub</a>
        <a href="https://github.com/bodasooqa/claudenv/blob/main/LICENSE">MIT License</a>
        <span class="dim">Not affiliated with Anthropic.</span>
      </div>
      <p class="footer-credit">Built by <a href="https://github.com/bodasooqa">@bodasooqa</a>.</p>
    </footer>
  </main>
```

- [ ] **Step 2: Add `sr-only` utility to `docs/style.css`**

Append to the end of `docs/style.css`:

```css
.sr-only {
  position: absolute;
  width: 1px; height: 1px;
  padding: 0; margin: -1px;
  overflow: hidden;
  clip: rect(0,0,0,0);
  white-space: nowrap;
  border: 0;
}
```

- [ ] **Step 3: Verify in browser**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected: all content visible (unstyled but readable). All four sections present, badges show as images, links work, no console errors. The terminal body is empty (animation script runs later).

- [ ] **Step 4: Commit**

```bash
git add docs/index.html docs/style.css
git commit -m "Add full semantic HTML for landing sections"
```

---

## Task 4: Style hero + implement copy-to-clipboard

**Files:**
- Modify: `docs/style.css` (hero styles)
- Modify: `docs/app.js` (copy-to-clipboard handler)

- [ ] **Step 1: Append hero styles to `docs/style.css`**

```css
/* Hero */
.hero {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  align-items: flex-start;
}

.wordmark {
  font-size: clamp(2.5rem, 8vw, 5rem);
  font-weight: 700;
  letter-spacing: -0.02em;
}
.wordmark::before {
  content: ">_ ";
  color: var(--accent);
}

.tagline {
  font-size: clamp(1.1rem, 2.5vw, 1.5rem);
  margin: 0;
}
.subtagline {
  color: var(--fg-dim);
  margin: 0;
  max-width: 60ch;
}

.install {
  position: relative;
  width: 100%;
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0;
  display: flex;
  align-items: stretch;
  overflow: hidden;
}
.install pre {
  margin: 0;
  padding: 1rem 1.25rem;
  flex: 1;
  overflow-x: auto;
  font-size: 0.9rem;
  white-space: pre;
}
.install pre code::before {
  content: "$ ";
  color: var(--fg-dim);
}
.copy {
  background: transparent;
  border: 0;
  border-left: 1px solid var(--border);
  color: var(--fg-dim);
  padding: 0 1rem;
  cursor: pointer;
  font-family: var(--font);
  font-size: 0.85rem;
  transition: color 150ms ease, background 150ms ease;
}
.copy:hover {
  color: var(--accent);
  background: rgba(255, 122, 89, 0.08);
}
.copy[data-copied="true"] {
  color: var(--success);
}

.badges {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}
.badges img { display: block; height: 20px; }

.ctas {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  width: 100%;
}
.btn {
  display: inline-block;
  padding: 0.75rem 1.25rem;
  border-radius: 6px;
  font-weight: 500;
  font-size: 0.95rem;
  text-align: center;
  transition: background 150ms ease, color 150ms ease, border-color 150ms ease;
}
.btn-primary {
  background: var(--accent);
  color: var(--bg);
}
.btn-primary:hover {
  background: var(--accent-dim);
  color: var(--fg);
}
.btn-secondary {
  border: 1px solid var(--border);
  color: var(--fg);
}
.btn-secondary:hover {
  border-color: var(--accent);
  color: var(--accent);
}

@media (min-width: 640px) {
  .ctas {
    flex-direction: row;
    width: auto;
  }
}
```

- [ ] **Step 2: Replace `docs/app.js` with copy-to-clipboard handler**

```js
// claudenv landing — interactions

(function () {
  "use strict";

  function initCopy() {
    document.querySelectorAll("[data-copy]").forEach(function (btn) {
      btn.addEventListener("click", async function () {
        const targetSel = btn.getAttribute("data-copy");
        const target = document.querySelector(targetSel);
        if (!target) return;
        const text = target.textContent.trim();
        try {
          await navigator.clipboard.writeText(text);
        } catch (_err) {
          return;
        }
        const original = btn.textContent;
        btn.textContent = "Copied!";
        btn.setAttribute("data-copied", "true");
        setTimeout(function () {
          btn.textContent = original;
          btn.removeAttribute("data-copied");
        }, 1500);
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initCopy);
  } else {
    initCopy();
  }
})();
```

- [ ] **Step 3: Verify in browser**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected:
- Hero shows large `>_` orange prefix + "claudenv" wordmark.
- Tagline with "Claude Code" link in orange.
- Install command block has dark elevated background, the command shown with a dim `$ ` prefix and a "Copy" button on the right.
- Clicking "Copy" turns the button text green-ish ("Copied!") for 1.5s, and the install command is in your clipboard (paste to verify).
- Two CTA buttons: orange filled "View on GitHub" + outlined "See it in action".
- Badges render in a wrapping row.

- [ ] **Step 4: Commit**

```bash
git add docs/style.css docs/app.js
git commit -m "Style hero and add copy-to-clipboard for install command"
```

---

## Task 5: Animated terminal demo (CSS + JS controller)

**Files:**
- Modify: `docs/style.css` (terminal styles)
- Modify: `docs/app.js` (typing animation)

- [ ] **Step 1: Append terminal styles to `docs/style.css`**

```css
/* Terminal demo */
.demo-section {
  width: 100%;
  max-width: var(--demo-max);
  margin: 0 auto;
}
.terminal {
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
}
.terminal-bar {
  background: #0f0f0f;
  border-bottom: 1px solid var(--border);
  padding: 0.55rem 0.75rem;
  display: flex;
  gap: 0.4rem;
  align-items: center;
}
.dot {
  width: 11px; height: 11px;
  border-radius: 50%;
  display: inline-block;
}
.dot-r { background: #ff5f57; }
.dot-y { background: #febc2e; }
.dot-g { background: #28c840; }

.terminal-body {
  margin: 0;
  padding: 1.25rem 1.25rem 1.5rem;
  font-size: clamp(0.8rem, 1.6vw, 0.95rem);
  line-height: 1.55;
  min-height: 16em;
  white-space: pre-wrap;
  word-break: break-word;
}
.terminal-body .prompt { color: var(--fg-dim); }
.terminal-body .input { color: var(--fg); }
.terminal-body .output { color: var(--fg-dim); }
.terminal-body .ok { color: var(--success); }
.terminal-body .caret {
  display: inline-block;
  width: 0.55ch;
  background: var(--accent);
  color: var(--accent);
  margin-left: 1px;
  animation: blink 1s steps(2, start) infinite;
}
@keyframes blink {
  to { visibility: hidden; }
}
@media (prefers-reduced-motion: reduce) {
  .terminal-body .caret { animation: none; }
}
```

- [ ] **Step 2: Append terminal animation controller to `docs/app.js`**

Append at the end of `docs/app.js`, before the closing `})();`:

```js
  // --- Terminal animation ---
  const SCRIPT = [
    { kind: "prompt" },
    { kind: "input", text: "claudenv import default", typeMs: 38 },
    { kind: "newline" },
    { kind: "output", text: "✓ imported ~/.claude as 'default'", cls: "ok", instant: true },
    { kind: "newline" },
    { kind: "prompt" },
    { kind: "input", text: "claudenv add work", typeMs: 38 },
    { kind: "newline" },
    { kind: "output", text: "✓ created account 'work'", cls: "ok", instant: true },
    { kind: "newline" },
    { kind: "prompt" },
    { kind: "input", text: "claudenv use work", typeMs: 38 },
    { kind: "newline" },
    { kind: "output", text: "switched to: work", cls: "output", instant: true },
    { kind: "newline" },
    { kind: "prompt" },
    { kind: "input", text: "claude", typeMs: 60 },
    { kind: "newline" },
    { kind: "output", text: "(launches with the 'work' profile)", cls: "output", instant: true },
    { kind: "pause", ms: 1800 }
  ];

  const FINAL_STATE_HTML = SCRIPT
    .filter(function (s) { return s.kind !== "pause"; })
    .map(function (s) {
      if (s.kind === "prompt") return '<span class="prompt">$ </span>';
      if (s.kind === "newline") return "\n";
      if (s.kind === "input") return '<span class="input">' + escapeHtml(s.text) + "</span>";
      if (s.kind === "output") return '<span class="' + s.cls + '">' + escapeHtml(s.text) + "</span>";
      return "";
    }).join("");

  function escapeHtml(s) {
    return s.replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function sleep(ms) {
    return new Promise(function (r) { setTimeout(r, ms); });
  }

  async function runTerminal(el) {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) {
      el.innerHTML = FINAL_STATE_HTML;
      return;
    }

    while (true) {
      el.innerHTML = "";
      const caret = document.createElement("span");
      caret.className = "caret";
      caret.textContent = " ";
      el.appendChild(caret);

      for (const step of SCRIPT) {
        if (step.kind === "prompt") {
          const span = document.createElement("span");
          span.className = "prompt";
          span.textContent = "$ ";
          el.insertBefore(span, caret);
          await sleep(220);
        } else if (step.kind === "input") {
          const span = document.createElement("span");
          span.className = "input";
          el.insertBefore(span, caret);
          for (const ch of step.text) {
            span.textContent += ch;
            await sleep(step.typeMs);
          }
          await sleep(280);
        } else if (step.kind === "newline") {
          el.insertBefore(document.createTextNode("\n"), caret);
        } else if (step.kind === "output") {
          const span = document.createElement("span");
          span.className = step.cls;
          span.textContent = step.text;
          el.insertBefore(span, caret);
          await sleep(420);
        } else if (step.kind === "pause") {
          await sleep(step.ms);
        }
      }
    }
  }

  function initTerminal() {
    const el = document.querySelector("[data-terminal]");
    if (!el) return;
    runTerminal(el);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initTerminal);
  } else {
    initTerminal();
  }
```

- [ ] **Step 3: Verify in browser**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected:
- Below the hero, a dark terminal window with three traffic-light dots (red/yellow/green) appears.
- A blinking orange caret leads the typed text.
- `claudenv import default` types out at ~human speed, then a green `✓ imported ~/.claude as 'default'` line appears below.
- Sequence continues through `add work`, `use work`, `claude`, then pauses ~1.8s and restarts from the top.
- In macOS System Settings > Accessibility > Display, enable "Reduce motion", reload — the terminal should render the final state statically with no typing or blinking.

- [ ] **Step 4: Commit**

```bash
git add docs/style.css docs/app.js
git commit -m "Add animated terminal demo with reduced-motion fallback"
```

---

## Task 6: Style feature cards

**Files:**
- Modify: `docs/style.css` (cards grid)

- [ ] **Step 1: Append card styles to `docs/style.css`**

```css
/* Feature cards */
.features { width: 100%; }
.cards {
  list-style: none;
  padding: 0;
  margin: 0;
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}
.card {
  background: var(--bg-elev);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.card-num {
  color: var(--accent-dim);
  font-size: 0.8rem;
  letter-spacing: 0.05em;
}
.card h3 {
  font-size: 1.05rem;
  font-weight: 500;
}
.card p {
  margin: 0;
  color: var(--fg-dim);
  font-size: 0.95rem;
}
.card code {
  color: var(--fg);
  background: rgba(255, 255, 255, 0.04);
  padding: 0 0.25rem;
  border-radius: 3px;
}

@media (min-width: 640px) {
  .cards {
    grid-template-columns: 1fr 1fr;
    gap: 1.25rem;
  }
}
```

- [ ] **Step 2: Verify in browser**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected:
- Four cards below the terminal demo.
- On viewports < 640px: single column.
- On viewports ≥ 640px: 2×2 grid.
- Each card: dimmed orange `[01]`/`[02]`/`[03]`/`[04]` label at top, title, body in dimmer gray, inline `code` snippets with a subtle highlight background.
- Resize the window across the 640px threshold to confirm the breakpoint switch.

- [ ] **Step 3: Commit**

```bash
git add docs/style.css
git commit -m "Style feature cards with responsive 2x2 grid"
```

---

## Task 7: Style footer + add favicon + add meta tags

**Files:**
- Modify: `docs/style.css` (footer styles)
- Modify: `docs/index.html` (favicon link, OG/twitter meta)
- Create: `docs/favicon.svg`

- [ ] **Step 1: Append footer styles to `docs/style.css`**

```css
/* Footer */
.footer {
  border-top: 1px solid var(--border);
  padding-top: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  font-size: 0.85rem;
}
.footer-row {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  align-items: center;
}
.footer .dim { color: var(--fg-dim); }
.footer-credit {
  margin: 0;
  color: var(--fg-dim);
}
```

- [ ] **Step 2: Create `docs/favicon.svg`**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <rect width="32" height="32" rx="6" fill="#0a0a0a"/>
  <text x="6" y="22" font-family="ui-monospace, Menlo, monospace" font-size="16" font-weight="700" fill="#ff7a59">&gt;_</text>
</svg>
```

- [ ] **Step 3: Add favicon + OG/Twitter meta in `<head>` of `docs/index.html`**

Insert these lines right after the existing `<meta name="description" ...>` line:

```html
  <link rel="icon" type="image/svg+xml" href="favicon.svg">
  <meta property="og:title" content="claudenv — nvm-style account manager for Claude Code">
  <meta property="og:description" content="Set a default account, override per-project, optionally auto-switch on cd. Zero dependencies.">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://bodasooqa.github.io/claudenv/">
  <meta name="twitter:card" content="summary">
```

- [ ] **Step 4: Verify in browser**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected:
- Browser tab icon is an orange `>_` glyph on dark background.
- Footer at bottom: thin top border, "GitHub" + "MIT License" links in orange, "Not affiliated with Anthropic." in dimmed gray, "Built by @bodasooqa" credit on a second line.
- View page source: OG meta tags present.

- [ ] **Step 5: Commit**

```bash
git add docs/style.css docs/index.html docs/favicon.svg
git commit -m "Add footer styles, favicon, and OG meta tags"
```

---

## Task 8: Polish — fade-in, reduced motion, a11y check

**Files:**
- Modify: `docs/style.css` (hero fade-in, focus polish)

- [ ] **Step 1: Append intro animation + reduced-motion gate to `docs/style.css`**

```css
/* Intro animation */
@media (prefers-reduced-motion: no-preference) {
  .hero {
    animation: fade-up 400ms ease-out both;
  }
  @keyframes fade-up {
    from { opacity: 0; transform: translateY(8px); }
    to { opacity: 1; transform: none; }
  }
}

/* Scroll target offset (anchor link from CTA to demo) */
.demo-section { scroll-margin-top: 1rem; }
```

- [ ] **Step 2: Verify in browser**

Run: `python3 -m http.server 8000 -d docs`
Open: `http://localhost:8000`
Expected:
- On page load, the hero fades in subtly from 8px below over ~400ms.
- Click "See it in action" CTA — page smoothly scrolls (browser default) to the terminal demo.
- Tab through interactive elements (install code, Copy button, badges, CTAs, GitHub link, MIT link, @bodasooqa link). Each focused element shows a 2px orange outline with 3px offset.
- Enable "Reduce motion" in OS settings, reload — hero appears instantly, no fade.

- [ ] **Step 3: Manual a11y spot-check**

Open DevTools → Lighthouse → run Accessibility audit (mobile or desktop, both fine).
Expected: score ≥ 95. Common findings to ignore: contrast ratio for the dimmed footer text (intentional design tradeoff). If anything else flags red, fix it now.

- [ ] **Step 4: Commit**

```bash
git add docs/style.css
git commit -m "Add hero intro animation and scroll-margin polish"
```

---

## Task 9: Cross-device responsive smoke test + screenshot

**Files:**
- (Read-only verification — no source changes unless issues found)

- [ ] **Step 1: Mobile viewport check**

Run: `python3 -m http.server 8000 -d docs`
Open Chrome DevTools → Device toolbar → set viewport to 375 × 667 (iPhone SE size).
Expected:
- Single column layout for cards.
- CTA buttons stack vertically.
- Terminal demo scales down, text remains legible (≥ 12px effective).
- Install command block is horizontally scrollable inside its container (the curl URL is long); the Copy button stays anchored to the right edge.
- No horizontal page scroll. No text overflowing its container.

- [ ] **Step 2: Tablet viewport check**

Set viewport to 768 × 1024.
Expected:
- Cards in 2×2 grid.
- CTAs side-by-side.
- All content within max-width centered.

- [ ] **Step 3: Wide viewport check**

Set viewport to 1440 × 900.
Expected:
- Content stays max-width 720px and centered (terminal demo allowed up to 960px).
- Lots of breathing room left/right — confirms the design doesn't stretch full-width.

- [ ] **Step 4: Fix anything found**

If you found a layout issue, fix it in `docs/style.css` and re-verify. If everything looks good, no changes — skip to the commit step.

- [ ] **Step 5: Commit (only if you made fixes)**

```bash
git add docs/style.css
git commit -m "Responsive fixes from cross-device smoke test"
```

If no fixes were needed, no commit. Move on.

---

## Task 10: Enable GitHub Pages + update README

**Files:**
- Modify: `README.md` (add link to live site)

- [ ] **Step 1: Push the branch**

```bash
git push origin main
```

- [ ] **Step 2: Enable GitHub Pages in repo settings**

This is a manual step in the GitHub web UI. Go to:
`https://github.com/bodasooqa/claudenv/settings/pages`

Under **Build and deployment**:
- **Source:** *Deploy from a branch*
- **Branch:** `main`, folder `/docs`

Click **Save**. GitHub takes 30-120 seconds to build and serve the first deploy.

- [ ] **Step 3: Verify live site**

Wait ~1 minute, then open: `https://bodasooqa.github.io/claudenv/`
Expected: the landing renders identically to local. Test the Copy button and the animation.

- [ ] **Step 4: Add live-site link to top of `README.md`**

Open `README.md` and find the badges block (lines 3-6). Right after the closing badge line and the blank line that follows, insert this paragraph:

```markdown
🔗 **Site:** https://bodasooqa.github.io/claudenv/
```

The result should look like:

```markdown
# claudenv

[![ShellCheck]...
[![License: MIT]...
![macOS]...
![Linux]...

🔗 **Site:** https://bodasooqa.github.io/claudenv/

An **nvm-style** account manager...
```

- [ ] **Step 5: Commit and push**

```bash
git add README.md
git commit -m "Link to landing page from README"
git push origin main
```

- [ ] **Step 6: Final verification**

Open the live site one more time and confirm:
- HTTPS works.
- Page loads under ~2s on a normal connection.
- Copy button works on the deployed URL.
- Animation plays.
- All links go to the correct GitHub URLs.

If anything is broken, debug locally first, then push the fix.

---

## Done

Landing is live at `https://bodasooqa.github.io/claudenv/`, README links to it, all source lives in `/docs` with no build step. Future updates: edit files in `/docs`, push to `main`, GH Pages redeploys automatically within ~1 minute.
