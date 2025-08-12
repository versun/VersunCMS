% rebase('layouts/application', title='Home', site_settings=site_settings)

<h1>Latest Articles</h1>

% include('_article_list', articles=articles, markdown2=markdown2)
