% rebase('layouts/application', title=article.title + " | " + site_settings.get('title', 'VersunCMS'), site_settings=site_settings, navbar_items=navbar_items)

<article>
  <small style="color:grey">created: {{article.created_at.strftime('%Y-%m-%d') if hasattr(article.created_at, 'strftime') else article.created_at}}, updated: {{article.updated_at.strftime('%Y-%m-%d') if hasattr(article.updated_at, 'strftime') else article.updated_at}}</small>
  <h2>{{article.title}}</h2>
  {{!article.content}}
</article>

% if article.social_media_posts:
  <br>
  <b>Discussion on </b>
  % mastodon_post = None
  % twitter_post = None  
  % bluesky_post = None
  % for post in article.social_media_posts:
    % if post.platform == 'mastodon':
      % mastodon_post = post
    % elif post.platform == 'twitter':
      % twitter_post = post
    % elif post.platform == 'bluesky':
      % bluesky_post = post
    % end
  % end
  % if mastodon_post and mastodon_post.url:
    <a href="{{mastodon_post.url}}" target="_blank">Mastodon</a>,
  % end
  % if twitter_post and twitter_post.url:
    <a href="{{twitter_post.url}}" target="_blank">X</a>,
  % end
  % if bluesky_post and bluesky_post.url:
    <a href="{{bluesky_post.url}}" target="_blank">Bluesky</a>.
  % end
% end
<hr>
<div class="giscus"></div>
{{!site_settings.get('giscus', '')}}
