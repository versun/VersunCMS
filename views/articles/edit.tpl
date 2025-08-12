% rebase('layouts/application', title="Editing", site_settings=site_settings, navbar_items=navbar_items)
% include('admin/_admin_bar')
% include('articles/_form', article=article, errors=errors if defined('errors') else [], crossposts=crossposts, newsletter_enabled=newsletter_enabled, current_time=current_time)
