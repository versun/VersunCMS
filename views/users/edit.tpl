% rebase('layouts/application', title="Account Settings", site_settings=site_settings, navbar_items=navbar_items)

% include('admin/_admin_bar')
<h3>Account Settings</h3>

<form method="post" action="/users/{{user.id}}">
  % if defined('errors') and errors:
    <div style="color: red">
      <h3>{{len(errors)}} error{{ 's' if len(errors) > 1 else '' }} prohibited this update:</h3>
      <ul>
        % for error in errors:
          <li>{{error}}</li>
        % end
      </ul>
    </div>
  % end

  <div>
    <label for="user_name">Username</label>
    <input type="text" id="user_name" name="user_name" value="{{user.user_name if user else ''}}">
  </div>

  <div>
    <label for="password">New Password</label>
    <input type="password" id="password" name="password">
  </div>

  <div>
    <label for="password_confirmation">Confirm New Password</label>
    <input type="password" id="password_confirmation" name="password_confirmation">
  </div>

  <div>
    <input type="submit" value="Update Account" class="admin-button">
  </div>
</form>
