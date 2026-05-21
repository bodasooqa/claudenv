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
})();
