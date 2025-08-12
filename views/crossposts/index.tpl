% rebase('layouts/application', site_settings=site_settings, navbar_items=navbar_items)

% include('admin/_admin_bar')
<h3>CrossPost Settings</h3>
<fieldset>
  <legend><h4>Mastodon</h4></legend>
  <p class="text-muted">Get credentials: Open Mastodon -> Preferences -> Development -> New application | Scope: profile,write:statuses</p>
  <form method="post" action="/crossposts/mastodon">
    <input type="hidden" name="platform" value="mastodon">
    
    <div class="form-group">
      <label for="mastodon_enabled">Enable Mastodon CrossPost</label>
      <input type="checkbox" id="mastodon_enabled" name="enabled" {{'checked' if mastodon and mastodon.enabled else ''}}>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      % for config in configs:
        <tr>
          <td>{{config.platform.capitalize()}}</td>
          <td>{{'Yes' if config.enabled else 'No'}}</td>
          <td><a href="#">Edit</a></td>
        </tr>
      % end
    </tbody>
  </table>
</div>
      <label for="server_url">Server URL</label>
      <input type="text" name="server_url" id="server_url" placeholder="https://bsky.social/xrpc" />
    </div>

    <div class="form-actions">
      <input type="submit" value="Save" class="btn btn-primary" />
      <button type="button" class="btn btn-secondary verify-btn" data-platform="bluesky">Verify</button>
    </div>
</fieldset>

<h5 class="mb-0">Logs</h5>
<table class="table table-striped">
  <thead>
  <tr>
    <th>Time</th>
    <th>Level</th>
    <th>Description</th>
  </tr>
  </thead>
  <tbody>
  <% @activity_logs.each do |log| %>
    <tr class="<%= case log.level&.to_sym
                   when :error then 'table-danger'
                   when :warn then 'table-warning'
                   when :info then 'table-success'
                   else ''
                   end %>">
      <td><%= log.created_at.strftime('%Y-%m-%d %H:%M:%S') %></td>
      <td><span class="badge <%= case log.level&.to_sym
                                 when :error then 'bg-danger'
                                 when :warn then 'bg-warning'
                                 when :info then 'bg-success'
                                 else 'bg-secondary'
                                 end %>">
        <%= log.level&.capitalize || 'Unknown' %>
      </span></td>
      <td><%= log.description %></td>
    </tr>
  <% end %>
  </tbody>
</table>

<% content_for :javascript do %>
<script>
document.addEventListener('turbo:load', function() {
  const verifyButtons = document.querySelectorAll('.verify-btn');
  
  verifyButtons.forEach(button => {
    button.addEventListener('click', function() {
      const platform = this.dataset.platform;
      const form = this.closest('form');
      const formData = new FormData(form);
      const button = this;
      
      // Convert FormData to JSON object
      const jsonData = {};
      formData.forEach((value, key) => {
        if (key.startsWith('crosspost')) {
          const cleanKey = key.replace('crosspost[', '').replace(']', '');
          jsonData[cleanKey] = value;
        }
      });
      
      // Disable button and show loading state
      button.disabled = true;
      const originalText = button.innerHTML;
      button.innerHTML = 'Verifying...';
      
      fetch(`/crossposts/${platform}/verify`, {
        method: 'POST',
        body: JSON.stringify({ crosspost: jsonData }),
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Content-Type': 'application/json'
        },
        credentials: 'same-origin'
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        if (data.status === 'success') {
          alert(data.message);
        } else {
          alert(data.message);
        }
      })
      .catch(error => {
        alert('An error occurred during verification.');
        console.error('Error:', error);
      })
      .finally(() => {
        // Re-enable button and restore original text
        button.disabled = false;
        button.innerHTML = originalText;
      });
    });
  });
});
</script>
<% end %>