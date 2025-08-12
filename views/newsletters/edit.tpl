% rebase('layouts/application', title="Newsletter Settings", site_settings=site_settings, navbar_items=navbar_items)

% include('admin/_admin_bar')

<h3>Newsletter Settings</h3>

<form method="post" action="/newsletters/update">
  <div class="form-group">
    <label for="enabled">Enable Newsletter</label>
    <input type="checkbox" id="enabled" name="enabled" {{'checked' if listmonk and listmonk.enabled else ''}}>
  </div>

  <div>
    <label for="url">Listmonk URL</label>
    <input type="text" id="url" name="url" placeholder="https://example.com" value="{{listmonk.url if listmonk else ''}}">
  </div>

  <div>
    <label for="username">Username</label>
    <input type="text" id="username" name="username" value="{{listmonk.username if listmonk else ''}}">
  </div>

  <div>
    <label for="api_key">API Key</label>
    <input type="text" id="api_key" name="api_key" value="{{newsletter.api_key or ''}}">
  </div>

  <!-- Dynamic lists and templates will be added later -->

  <div>
    <input type="submit" value="Save">
  </div>
</form>

<h5 class="mb-0">Logs</h5>
<p><em>Activity logs will be implemented later.</em></p>
