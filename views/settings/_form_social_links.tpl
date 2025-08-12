<b>Social Links</b>

% for platform, config in social_platforms.items():
<div class="social-platform">
  <span>{{platform.capitalize()}}</span>
  <input type="url" name="social_links[{{platform}}][url]" 
         value="{{get('social_links', {}).get(platform, {}).get('url', '')}}" 
         placeholder="Enter {{platform}} URL" />
</div>
% end
