<table width="100%">
  <tr>
    <td><h2><a href="/articles/{{article.slug}}">{{article.title}}</a></h2></td>
    <td align="right" width="10%">
      <small class="meta">
        {{article.created_at.strftime('%Y-%m-%d') if hasattr(article.created_at, 'strftime') else article.created_at}}
      </small>
    </td>
  </tr>
</table>
