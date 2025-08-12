import json
import httpx
from huey import SqliteHuey
from models import Article, Crosspost

# Use the same SQLite database for simplicity, Huey will use its own tables.
huey = SqliteHuey(filename='versuncms.db')

@huey.task()
def crosspost_article(article_id):
    """Fetches an article and posts it to all enabled platforms."""
    try:
        article = Article.get_by_id(article_id)
    except Article.DoesNotExist:
        print(f"[Crosspost Task] Article with ID {article_id} not found.")
        return

    enabled_configs = Crosspost.select().where(Crosspost.enabled == True)

    for config in enabled_configs:
        if config.platform == 'mastodon':
            post_to_mastodon(article, config)
        # Add other platforms like 'twitter', 'bluesky' here in the future.

def post_to_mastodon(article, config):
    """Posts a status to a Mastodon instance."""
    try:
        settings = json.loads(config.settings)
        server_url = settings.get('server_url')
        client_key = settings.get('client_key')
        client_secret = settings.get('client_secret')
        access_token = settings.get('access_token')

        # For now, we only need the access token to post a status.
        # The client key/secret would be needed for a full OAuth flow.
        if not server_url or not access_token:
            print(f"[Mastodon] Incomplete configuration for {config.platform}.")
            return

        # Construct the status text
        status_text = f"{article.title}\n\n{article.description}"

        response = httpx.post(
            f"{server_url}/api/v1/statuses",
            headers={
                'Authorization': f'Bearer {access_token}'
            },
            json={
                'status': status_text,
                'visibility': 'public'
            }
        )

        response.raise_for_status() # Raise an exception for bad status codes
        print(f"[Mastodon] Successfully posted article '{article.title}' to {server_url}.")

    except Exception as e:
        print(f"[Mastodon] Failed to post article '{article.title}': {e}")
