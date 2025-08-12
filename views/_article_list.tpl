<div class="article-list">
  % for article in articles:
  <hr>
    % include('articles/_article_meta', article=article)
    % if article.description:
      {{!article.description}}
    % else:
      {{!article.content}}
    % end
    
  % end
</div>
<hr>
<!-- Pagination will be added later -->