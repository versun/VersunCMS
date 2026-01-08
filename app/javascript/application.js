// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

const highlightCssHref =
  "https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/github-dark.min.css";
let highlightPromise;

function enableAsyncStyles(root = document) {
  if (!root?.querySelectorAll) return;

  const links = root.querySelectorAll("link[data-async-media]");
  if (links.length === 0) return;

  links.forEach((link) => {
    if (link.media === "all") return;

    const activate = () => {
      link.media = "all";
      link.removeAttribute("data-async-media");
    };

    link.addEventListener("load", activate, { once: true });
    if (link.sheet) activate();
  });
}

function loadHighlightCssIfNeeded() {
  if (document.getElementById("highlight-css")) return;
  const link = document.createElement("link");
  link.id = "highlight-css";
  link.rel = "stylesheet";
  link.href = highlightCssHref;
  link.crossOrigin = "anonymous";
  link.referrerPolicy = "no-referrer";
  document.head.appendChild(link);
}

function loadHighlightIfNeeded(root = document) {
  if (!root?.querySelectorAll) return;

  const blocks = root.querySelectorAll("pre code");
  if (blocks.length === 0) return;

  loadHighlightCssIfNeeded();

  if (!highlightPromise) {
    highlightPromise = import("highlight.js").then(
      (module) => module.default || module
    );
  }

  highlightPromise.then((hljs) => {
    blocks.forEach((block) => {
      if (!block.classList.contains("hljs")) {
        hljs.highlightElement(block);
      }
    });
  });
}

function enhancePage() {
  enableAsyncStyles();
  loadHighlightIfNeeded();
}

enableAsyncStyles();

document.addEventListener("turbo:load", enhancePage);
document.addEventListener("DOMContentLoaded", enhancePage);
document.addEventListener("turbo:frame-load", (event) => {
  const frame = event.target;
  requestAnimationFrame(() => {
    loadHighlightIfNeeded(frame);
  });
});
