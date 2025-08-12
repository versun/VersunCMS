% rebase('layouts/application', title="Editing", site_settings=site_settings, navbar_items=navbar_items)
% include('admin/_admin_bar')
% include('_page_form', page=page, errors=errors if defined('errors') else [], current_time=current_time)
