// claudenv landing — interactions

(function () {
  "use strict";

  function initCopy() {
    document.querySelectorAll("[data-copy]").forEach(function (btn) {
      const originalText = btn.textContent;
      const originalLabel = btn.getAttribute("aria-label");
      btn.addEventListener("click", async function () {
        if (btn.dataset.copied === "true") return;
        const targetSel = btn.getAttribute("data-copy");
        const target = document.querySelector(targetSel);
        if (!target) return;
        const text = target.textContent.trim();
        try {
          await navigator.clipboard.writeText(text);
        } catch (_err) {
          return;
        }
        btn.textContent = "Copied!";
        if (originalLabel) btn.setAttribute("aria-label", "Copied");
        btn.setAttribute("data-copied", "true");
        setTimeout(function () {
          btn.textContent = originalText;
          if (originalLabel) btn.setAttribute("aria-label", originalLabel);
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
})();
