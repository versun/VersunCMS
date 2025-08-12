% rebase('layouts/application', title="Website Analytics", site_settings=site_settings, navbar_items=navbar_items)

<h3>Website Analytics</h3>

<div class="total-visits">
  <h4>Total Views: {{total_visits}}</h4>
</div>
    
<div style="display: flex; justify-content: space-between;">
  <div>
    <p>Pages</p>
    % if visits_by_path:
      % for path_data, count in visits_by_path.items():
        {{count}} - {{path_data.get('slug', 'Unknown')}}<br>
      % end
    % end
  </div>
  <div>
    <p>Referrers</p>
    % if referrers:
      % for referrer, count in referrers.items():
        {{count}} - {{referrer}}<br>
      % end
    % end
  </div>
</div>
<hr>
<div style="display: flex; justify-content: space-between;">
  <div>
    <p>Browsers</p>
    % if browsers:
      % for browser, count in browsers.items():
        {{count}} - {{browser}}<br>
      % end
    % end
  </div>
  <div>
    <p>OS</p>
    % if operating_systems:
      % for os, count in operating_systems.items():
        {{count}} - {{os}}<br>
      % end
    % end
  </div>
  <div>
    <p>Devices</p>
    % if devices:
      % for device, count in devices.items():
        {{count}} - {{device}}<br>
      % end
    % end
  </div>
</div>
