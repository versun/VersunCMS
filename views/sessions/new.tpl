% rebase('layouts/application', title="Sign In", site_settings=site_settings, navbar_items=navbar_items)

% if defined('alert') and alert:
<div style="color:red">{{alert}}</div>
% end
% if defined('notice') and notice:
<div style="color:green">{{notice}}</div>
% end

<form method="post" action="/login">
  <input type="text" name="user_name" required autofocus autocomplete="username" placeholder="Enter your username" value="{{get('user_name', '')}}" /><br>
  <input type="password" name="password" required autocomplete="current-password" placeholder="Enter your password" maxlength="72" /><br>
  <input type="submit" value="Sign in" />
</form>
