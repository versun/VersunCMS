% title = 'New Page'
% rebase('layouts/application', title="New", site_settings=site_settings, navbar_items=navbar_items)
% include('admin/_admin_bar')
<h3>New</h3>
% include('_page_form', page=page, errors=errors if defined('errors') else [], current_time=current_time)