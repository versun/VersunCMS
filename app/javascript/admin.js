let actionTextPromise;

function loadActionTextIfNeeded(root = document) {
  if (!root?.querySelector) return;
  if (!root.querySelector("trix-editor")) return;

  if (!actionTextPromise) {
    actionTextPromise = import("trix").then(() =>
      import("@rails/actiontext")
    );
  }

  return actionTextPromise;
}

function enhanceAdminPage() {
  loadActionTextIfNeeded();
}

document.addEventListener("turbo:load", enhanceAdminPage);
document.addEventListener("DOMContentLoaded", enhanceAdminPage);
document.addEventListener("turbo:frame-load", (event) => {
  loadActionTextIfNeeded(event.target);
});
