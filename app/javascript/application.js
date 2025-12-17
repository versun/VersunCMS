// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

// Keep initial JS small: load heavier modules only when needed.
// (Static pages benefit a lot from this.)

// Syntax highlight / content enhancements (only if content exists)
if (document.querySelector(".lexxy-content")) {
  import("lexxy");
}

// ActionText / Trix (only on pages that actually have an editor / trix content)
if (document.querySelector("trix-editor, [data-trix-editor], .trix-content")) {
  import("@rails/actiontext");
}
