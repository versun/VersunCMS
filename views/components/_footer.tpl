<footer>
  
<table width="100%">
  <tr>
    <td>{{!site_settings.get('footer', '')}}</td>
    <td align="right" width="50%">
      <div class="social-links">
        <a href="/rss" target="_blank" class="social-icon" rel="rss">
          <img src="/static/rss.svg" width="20" height="20" alt="RSS" class="social-icon"></a>
        % if site_settings.get('social_links'):
          % for platform, data in site_settings.get('social_links', {}).items():
            % if data.get('url'):
              <a rel="me" href="{{data['url']}}" target="_blank" class="social">
                <img src="/static/{{data.get('icon_path', '')}}"
                     width="20" height="20"
                     alt="{{platform.title()}}"
                     class="social-icon"
                     title="{{platform.title()}}"></a>
            % end
          % end
        % end
      </div>
    </td>
  </tr>
</table>

</footer>