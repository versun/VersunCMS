% title = article.title + ' | ' + site_settings.get('title', 'VersunCMS')
% rebase('layouts/application', title=title, site_settings=site_settings)

<article>
  <small style="color:grey">created: {{article.created_at.strftime('%Y-%m-%d')}}, updated: {{article.updated_at.strftime('%Y-%m-%d')}}</small>
  <h2>{{article.title}}</h2>
  <div>
    {{!markdown2.markdown(article.content or '')}}
  </div>
</article>

<hr>
