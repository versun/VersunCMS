<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/1.1">
  <url>
    <loc>{{site_settings.get('url', '')}}</loc>
    <lastmod>{{today_date}}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>

  % for page in pages:
  <url>
    <loc>{{site_settings.get('url', '')}}/pages/{{page.slug}}</loc>
    <lastmod>{{page.updated_at.strftime('%Y-%m-%d')}}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
  % end

  % for article in articles:
  <url>
    <loc>{{site_settings.get('url', '')}}/{{article_route_prefix}}/{{article.slug}}</loc>
    <lastmod>{{article.updated_at.strftime('%Y-%m-%d')}}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
  % end
</urlset>
