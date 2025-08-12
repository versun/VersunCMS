% rebase('layouts/application', title="Forgot your password?", site_settings=site_settings, navbar_items=navbar_items)

<h1>Forgot your password?</h1>

% if defined('alert') and alert:
<div style="color:red">{{alert}}</div>
% end

<form method="post" action="/passwords">
  <input type="text" name="user_name" required autofocus autocomplete="username" placeholder="Enter your username" value="{{get('user_name', '')}}" /><br>
  <input type="submit" value="Email reset instructions" />
</form>
