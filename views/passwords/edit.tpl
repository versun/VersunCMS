% rebase('layouts/application', title="Update your password", site_settings=site_settings, navbar_items=navbar_items)

<h1>Update your password</h1>

% if defined('alert') and alert:
<div style="color:red">{{alert}}</div>
% end

<form method="post" action="/password">
  <input type="hidden" name="_method" value="PUT">
  <input type="password" name="password" required autocomplete="new-password" placeholder="Enter new password" maxlength="72" /><br>
  <input type="password" name="password_confirmation" required autocomplete="new-password" placeholder="Repeat new password" maxlength="72" /><br>
  <input type="submit" value="Save" />
</form>
