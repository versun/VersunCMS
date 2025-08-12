<form method="post" action="/articles{{ '/' + article.slug + '/edit' if article.id else '' }}">
  % if defined('errors') and errors:
    <div style="color: red">
      <h3>{{len(errors)}} error{{ 's' if len(errors) > 1 else '' }} prohibited this article from being saved:</h3>

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
        <input type="text" id="title" name="title" value="{{article.title if article else ''}}" /><br/>
        <label for="slug">slug:</label>
        <input type="text" id="slug" name="slug" value="{{article.slug if article else ''}}" /><br/>
        <label for="created_at">created at:</label>
        <input type="datetime-local" id="created_at" name="created_at" 
               value="{{article.created_at.strftime('%Y-%m-%dT%H:%M') if article and article.created_at else ''}}" />
      </fieldset>
      
      <fieldset class="bordered-container bordered-fieldset">
        <legend>Content</legend>
        <textarea id="content" name="content" rows="20" cols="80" required>{{article.content if article else ''}}</textarea>
      </fieldset>

      <fieldset class="bordered-container bordered-fieldset">
        <legend>Description</legend>
        <textarea id="description" name="description" rows="3" cols="50">{{article.description if article else ''}}</textarea>
      </fieldset>
      
      <fieldset class="bordered-container bordered-fieldset">
        <legend>CrossPost</legend>
        
        % if crossposts and crossposts.get('mastodon', {}).get('enabled'):
          <div>
            <input type="checkbox" id="crosspost_mastodon" name="crosspost_mastodon" 
                   {{'checked' if article and article.crosspost_mastodon else ''}} />
            <label for="crosspost_mastodon">Post to Mastodon</label>
            <input type="text" name="social_media_posts[mastodon][url]" placeholder="Post URL" 
                   value="{{article.social_media_posts.get('mastodon', {}).get('url', '') if article else ''}}" />
            <input type="hidden" name="social_media_posts[mastodon][platform]" value="mastodon" />
          </div>
        % end
        
        % if crossposts and crossposts.get('twitter', {}).get('enabled'):
          <div>
            <input type="checkbox" id="crosspost_twitter" name="crosspost_twitter"
                   {{'checked' if article and article.crosspost_twitter else ''}} />
            <label for="crosspost_twitter">Post to Twitter</label>
            <input type="text" name="social_media_posts[twitter][url]" placeholder="Post URL"
                   value="{{article.social_media_posts.get('twitter', {}).get('url', '') if article else ''}}" />
            <input type="hidden" name="social_media_posts[twitter][platform]" value="twitter" />
          </div>
        % end
        
        % if crossposts and crossposts.get('bluesky', {}).get('enabled'):
          <div>
            <input type="checkbox" id="crosspost_bluesky" name="crosspost_bluesky"
                   {{'checked' if article and article.crosspost_bluesky else ''}} />
            <label for="crosspost_bluesky">Post to Bluesky</label>
            <input type="text" name="social_media_posts[bluesky][url]" placeholder="Post URL"
                   value="{{article.social_media_posts.get('bluesky', {}).get('url', '') if article else ''}}" />
            <input type="hidden" name="social_media_posts[bluesky][platform]" value="bluesky" />
          </div>
        % end
        
        <a href="/crossposts">Go to Cross Post Settings</a>
      </fieldset>

      <fieldset class="bordered-container bordered-fieldset">
        <legend>Newsletter</legend>
        % if newsletter_enabled:
          <div>
            <input type="checkbox" id="send_newsletter" name="send_newsletter"
                   {{'checked' if article and article.send_newsletter else ''}} />
            <label for="send_newsletter">Send Newsletter</label>
          </div>
        % end
        <a href="/newsletters/edit">Go to Newsletter Settings</a>

      </fieldset>

      <fieldset class="bordered-container bordered-fieldset">
        <legend>Actions</legend>
          <div>
            <select id="status_select" name="status" required>
              <option value="">choose a status</option>
              % for status in ['draft', 'published', 'schedule']:
                <option value="{{status}}" 
                        {{'selected' if article and article.status == status else ''}}>{{status}}</option>
              % end
            </select>
          </div>

          <div class="scheduled-at" id="scheduled_at" 
               style="display: {{'block' if article and article.status == 'schedule' else 'none'}}">
            <input type="datetime-local" id="scheduled_at" name="scheduled_at"
                   value="{{article.scheduled_at.strftime('%Y-%m-%dT%H:%M') if article and article.scheduled_at else ''}}" />
            Current Date Time: {{current_time.strftime('%Y/%m/%d %I:%M %p %Z') if current_time else ''}}
          </div>
        
          <div>
          <input type="submit" value="save" />
          % if article and article.id:
            <a href="/articles/{{article.slug}}" 
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
