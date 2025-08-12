<!DOCTYPE html>
<html>
  <head>
    
    <title>{{ content_for_title if defined('content_for_title') else site_settings.get('title', 'VersunCMS') }}</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">

    % if defined('head_content'):
    {{!head_content}}
    % end

    <!-- Enable PWA manifest for installable apps -->
    <!-- <link rel="manifest" href="/pwa/manifest.json"> -->

    <link rel="icon" href="/static/icon.png" type="image/png">
    <link rel="icon" href="/static/icon.svg" type="image/svg+xml">
    <link rel="icon" href="/static/favicon.ico" sizes="32x32">
    <link rel="apple-touch-icon" href="/static/icon.png">
    <link rel="alternate" type="application/rss+xml" title="{{ site_settings.get('title', 'VersunCMS') }}" href="/feed">
    
    <!-- Includes all stylesheet files -->
    <link rel="stylesheet" href="/static/style.css">
    
    {{!site_settings.get('head_code', '')}}

    <style>
        body {
            max-width: 880px;
            margin: 0 auto;
            padding: 10px;
            background: #f8f4ee;
        }
        a:hover {
            text-decoration: underline wavy;
            background-color: #f0f0f0;
        }
      {{!site_settings.get('custom_css', '')}}
    </style>
  </head>

  <body>
    <header>
      <table width="100%">
        <tr>
          <td>
            <h1><a href="/">{{ site_settings.get('title', 'VersunCMS') }}</a></h1>
          </td>
          <td align="right" width="50%">
              <p class="description">{{ site_settings.get('description', '') }}</p>
          </td>
        </tr>
      </table>
                  
      <table width="100%">
        <tr>
          <td>
            % include('components/_nav_bar', navbar_items=navbar_items if defined('navbar_items') else [], site_settings=site_settings)
          </td>
          <td align="right" width="30%">
            <form action="/" method="get" class="search-form">
              <input type="search" name="q" value="{{ get('q', '') }}" placeholder="Search...">
              <input type="submit" value="Search">
            </form>
          </td>
        </tr>
      </table>
    </header>

    <hr>

    {{!site_settings.get('tool_code', '')}}
    
    <main> 
      {{!base}}
    </main>
    
    <hr>

    % include('components/_footer', site_settings=site_settings)
    % if defined('javascript_content'):
    {{!javascript_content}}
    % end
  </body>
</html>
