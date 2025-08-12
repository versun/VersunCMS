% rebase('layouts/application', title="Admin", site_settings=site_settings, navbar_items=navbar_items)
  
% include('admin/_admin_bar')
% include('admin/_post_status', scope=articles if defined('articles') else [], controller_name='admin', action_name='posts', status=current_status if defined('current_status') else 'publish')
<a href="/articles/new">New</a>
% if articles:
% include('admin/_article_list', posts=articles)
% else:
<p>No Posts Found</p>
% end
