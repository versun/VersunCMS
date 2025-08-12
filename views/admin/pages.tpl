% rebase('layouts/application', title="Admin", site_settings=site_settings, navbar_items=navbar_items)

% include('admin/_admin_bar')
% include('admin/_post_status', scope=pages if defined('pages') else [], controller_name='admin', action_name='pages', status=status if defined('status') else 'publish')
<a href="/pages/new">New</a>
% if pages:
% include('admin/_page_list', posts=pages)
% else:
<p>No Pages Found</p>
% end
