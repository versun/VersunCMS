% title = page.title + ' | ' + site_settings.get('title', 'VersunCMS')
% rebase('layouts/application', title=page.title + " | " + site_settings.get('title', 'VersunCMS'), site_settings=site_settings, navbar_items=navbar_items)

<article>
  <div class="article-content">
    {{!page.content}}
  </div>
</article>
<hr>
<div class="giscus"></div>
{{!site_settings.get('giscus', '')}}
