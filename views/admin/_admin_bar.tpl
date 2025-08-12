% setdefault('head_content', '')
% head_content = head_content + '''
<style>
    trix-toolbar {
        position: sticky;
        top: 0;
        z-index: 1;
        background-color: white;
    }
    .status-tab.active {
        background-color: cornflowerblue;
        color: white;
    }
</style>
'''

% if defined('notice') and notice:
<p style="color: green">{{notice}}</p>
% end
% if defined('alert') and alert:
<p style="color: red">{{alert}}</p>
% end

<table width="100%">
  <tr>
    <td>
      <a href="/admin/posts" class="admin-button">Posts</a> |
      <a href="/admin/pages" class="admin-button">Pages</a>
    </td>
    <td>
      <a href="/admin/tools/export" class="admin-button">Export</a> |
      <a href="/admin/tools/import" class="admin-button">Import</a> |
      <a href="/admin/crossposts" class="admin-button">CrossPost</a> |
      <a href="/admin/newsletters/edit" class="admin-button">Newsletter</a>
    </td>
    <td>
      <a href="/admin/analytics" class="admin-button">Analytics</a> |
      <a href="/admin/settings" class="admin-button">Settings</a> |
      <a href="/users/1/edit" class="admin-button">Account</a>
    </td>

    <td align="right">
      <form method="post" action="/logout" style="display: inline;">
        <input type="submit" value="Logout" class="admin-button">
      </form>
    </td>
  </tr>
</table>
<hr>
