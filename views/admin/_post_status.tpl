<div class="status-tabs">
  <a href="/admin/posts?status=publish" class="status-tab {{'active' if current_status == 'publish' else ''}}">Published ({{status_counts.get('publish', 0)}})</a> -
  <a href="/admin/posts?status=draft" class="status-tab {{'active' if current_status == 'draft' else ''}}">Draft ({{status_counts.get('draft', 0)}})</a> -
  <a href="/admin/posts?status=schedule" class="status-tab {{'active' if current_status == 'schedule' else ''}}">Scheduled ({{status_counts.get('schedule', 0)}})</a> -
  <a href="/admin/posts?status=shared" class="status-tab {{'active' if current_status == 'shared' else ''}}">Shared ({{status_counts.get('shared', 0)}})</a> -
  <a href="/admin/posts?status=trash" class="status-tab {{'active' if current_status == 'trash' else ''}}">Trash ({{status_counts.get('trash', 0)}})</a>
</div>