% rebase('layouts/application', title="Import Data", site_settings=site_settings, navbar_items=navbar_items)

% include('admin/_admin_bar')
<h3>Import Data</h3>
<form method="post" action="/tools/import/from_rss" enctype="multipart/form-data">
  <label for="url">RSS URL:</label>
  <input type="text" name="url" id="url" required /><br>
  <input type="checkbox" name="import_images" value="1" id="import_images" />
  <label for="import_images">Import Images</label><br>
  <input type="submit" value="Import From RSS" class="admin-button" />
</form>
<br>
<h5 class="mb-0">Import History</h5>
<table class="table table-striped">
  <thead>
  <tr>
    <th>Time</th>
    <th>Level</th>
    <th>Description</th>
  </tr>
  </thead>
  <tbody>
  % for log in activity_logs:
    <tr class="% if log.level == 'error':
table-danger
% elif log.level == 'warn':
table-warning  
% elif log.level == 'info':
table-success
% end
">
      <td>{{log.created_at.strftime('%Y-%m-%d %H:%M:%S')}}</td>
      <td><span class="badge % if log.level == 'error':
bg-danger
% elif log.level == 'warn':
bg-warning
% elif log.level == 'info':
bg-success
% else:
bg-secondary
% end
">
            {{log.level.capitalize() if log.level else 'Unknown'}}
          </span></td>
      <td>{{log.description}}</td>
    </tr>
  % end
  </tbody>
</table>
