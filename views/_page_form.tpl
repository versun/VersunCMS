<form method="post" action="/pages{{ '/' + page.slug if page and page.id else '' }}">
  % if defined('errors') and errors:
    <div style="color: red">
      <h3>{{len(errors)}} error{{ 's' if len(errors) > 1 else '' }} prohibited this page from being saved:</h3>

      <ul>
        % for error in errors:
          <li>{{error}}</li>
        % end
      </ul>
    </div>
  % end
  <div>
      <fieldset class="bordered-container bordered-fieldset">
        <legend>Base</legend>
        <label for="title">title:</label>
        <input type="text" id="title" name="title" value="{{page.title if page else ''}}" required /><br/>
        <label for="slug">slug:</label>
        <input type="text" id="slug" name="slug" value="{{page.slug if page else ''}}" required /><br/>
        <label for="page_order">page order:</label>
        <input type="number" id="page_order" name="page_order" value="{{page.page_order if page else ''}}" required /><br/>
        <label for="redirect_url" class="form-label">redirect to(optional):</label>
        <input type="url" id="redirect_url" name="redirect_url" value="{{page.redirect_url if page else ''}}" class="form-control" placeholder="https://example.com" />
        
      </fieldset>
      
      <fieldset class="bordered-container bordered-fieldset">
        <legend>Content</legend>
        <textarea id="content" name="content" rows="20" cols="80" required>{{page.content if page else ''}}</textarea>
      </fieldset>
      
      <fieldset class="bordered-container bordered-fieldset">
        <legend>Actions</legend>
          <div>
            <select id="status_select" name="status" required>
              <option value="">choose a status</option>
              % for status in ['draft', 'published', 'schedule']:
                <option value="{{status}}" 
                        {{'selected' if page and page.status == status else ''}}>{{status}}</option>
              % end
            </select>
          </div>
          <div class="scheduled-at" id="scheduled_at" 
               style="display: {{'block' if page and page.status == 'schedule' else 'none'}}">
            <input type="datetime-local" id="scheduled_at" name="scheduled_at"
                   value="{{page.scheduled_at.strftime('%Y-%m-%dT%H:%M') if page and page.scheduled_at else ''}}" />
            Current Date Time: {{current_time.strftime('%Y/%m/%d %I:%M %p %Z') if current_time else ''}}
          </div>

          <div>
          <input type="submit" value="save" />
          % if page and page.id:
            <a href="/pages/{{page.slug}}" 
               onclick="return confirm('Are you sure?')" 
               data-method="delete">delete</a>
          % end
          </div>
      </fieldset>

  </div>

</form>

<script>
  function initializeScheduledAt() {
    const statusSelect = document.getElementById('status_select');
    const scheduledAtContainer = document.getElementById('scheduled_at');

    // 初始检查状态
    if (statusSelect.value === 'schedule') {
      scheduledAtContainer.style.display = 'block';
    }

    // 添加change事件监听
    statusSelect.addEventListener('change', function() {
      if (this.value === 'schedule') {
        scheduledAtContainer.style.display = 'block';
      } else {
        scheduledAtContainer.style.display = 'none';
      }
    });
  }

  // 同时支持传统加载和现代加载
  document.addEventListener("DOMContentLoaded", initializeScheduledAt);
</script>