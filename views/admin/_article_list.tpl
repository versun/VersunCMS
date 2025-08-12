<div class="articles-admin">     
  % for post in posts:

    <div class="row-actions">
        <a href="/articles/{{post.slug}}">view</a> |
        <a href="/articles/{{post.slug}}/edit">edit</a> |
        % if post.status != "trash":
          <a href="/articles/{{post.slug}}" onclick="return confirm('Move to trash?')" data-method="delete">trash</a> |
        % else:
          <a href="/articles/{{post.slug}}" onclick="return confirm('Delete permanently?')" data-method="delete">delete</a> |
        % end
      
        <a href="/articles/{{post.slug}}/edit" class="title">{{post.title}}</a>
    </div>
  % end
  <hr>
  <!-- Pagination will be added later -->
</div>

