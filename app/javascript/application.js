// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

// Keep initial JS small: load heavier modules only when needed.
// (Static pages benefit a lot from this.)

// Lazy load modules when needed (works with Turbo navigation)
function loadLexxyIfNeeded() {
  if (document.querySelector("lexxy-editor, .lexxy-content")) {
    import("lexxy");
  }
}

function loadActionTextIfNeeded() {
  if (document.querySelector("trix-editor, [data-trix-editor], .trix-content")) {
    import("@rails/actiontext");
  }
}

// Load on initial page load
loadLexxyIfNeeded();
loadActionTextIfNeeded();

// Load after Turbo navigation
document.addEventListener("turbo:load", () => {
  loadLexxyIfNeeded();
  loadActionTextIfNeeded();
});
