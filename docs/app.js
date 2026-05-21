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
