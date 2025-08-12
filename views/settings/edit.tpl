% rebase('layouts/application', title="Settings", site_settings=site_settings, navbar_items=navbar_items)

% include('admin/_admin_bar')

<form method="post" action="/settings">
  <input type="hidden" name="_method" value="PUT">
  
  % if defined('errors') and errors:
  <div style="color: red">
    <h3>{{len(errors)}} error(s) prohibited this setting from being saved:</h3>
    <ul>
      % for error in errors:
      <li>{{error}}</li>
      % end
    </ul>
  </div>
  % end

  <div class="field">
    <b><label for="title">Site Title</label></b>
    <input type="text" name="title" id="title" value="{{get('title', '')}}" />
  </div>

  <div class="field">
    <b><label for="description">Site Description</label></b>
    <input type="text" name="description" id="description" value="{{get('description', '')}}" />
  </div>

  <div class="field">
    <b><label for="author">Author</label></b>
    <input type="text" name="author" id="author" value="{{get('author', '')}}" />
  </div>

  <div class="field">
    <b><label for="url">Site URL</label></b>
    <input type="text" name="url" id="url" value="{{get('url', '')}}" />
  </div>

  <div class="field">
    <b><label for="time_zone">Timezone</label></b>
    <select name="time_zone" id="time_zone" class="form-select">
      % for tz in timezone_options:
      <option value="{{tz[1]}}" {{'selected' if tz[1] == get('time_zone', 'UTC') else ''}}>{{tz[0]}}</option>
      % end
    </select>
  </div>

  <div class="field">
    <b><label for="head_code">Head Code</label></b><br>
    <textarea name="head_code" id="head_code">{{get('head_code', '')}}</textarea>
  </div>

  <div class="field">
    <b><label for="giscus">Giscus Code</label></b><br>
    <textarea name="giscus" id="giscus">{{get('giscus', '')}}</textarea>
  </div>

  <div class="field">
    <b><label for="tool_code">Tool Code</label></b><br>
    <textarea name="tool_code" id="tool_code">{{get('tool_code', '')}}</textarea>
  </div>
  
  <div class="field">
    <b><label for="footer">Footer</label></b>
    <textarea name="footer" id="footer">{{get('footer', '')}}</textarea>
  </div>
      
  <div class="field">
    <b><label for="custom_css">Custom CSS</label></b><br>
    <textarea name="custom_css" id="custom_css">{{get('custom_css', '')}}</textarea>
  </div>
    
  <div class="field">
    % include('settings/_form_social_links')
  </div>

  <div class="actions">
    <input type="submit" value="Save" />
  </div>
</form>
<hr>
<div class="field">
  % include('settings/_form_static_files')
</div>
