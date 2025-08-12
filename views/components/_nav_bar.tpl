<nav>
  <div class="navbar-items">
    % if defined('navbar_items') and navbar_items:
      % for page in navbar_items:
        <span class="navbar-page">
          <a href="/pages/{{page.slug}}">{{page.title}}</a>
        </span> |
      % end
    % end
  </div>
</nav>
