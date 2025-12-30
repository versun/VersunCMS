// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import "trix";
import "@rails/actiontext";
import "highlight.js";

document.addEventListener("turbo:load", highlightAll);
document.addEventListener("DOMContentLoaded", highlightAll);

function highlightAll() {
  document.querySelectorAll("pre code").forEach((block) => {
    if (!block.classList.contains("hljs")) {
      hljs.highlightElement(block);
    }
  });
}
