from bottle import route, response, template
from models import Page, Article
from datetime import datetime

@route('/sitemap.xml')
def sitemap():
    """Generate XML sitemap."""
    # Get published articles and pages
    articles = Article.select().where(Article.status == 'publish')
    pages = Page.select().where(Page.status == 'publish')
    
    # Mock site settings
    site_settings = {
        'url': 'https://example.com'  # In real app, get from settings
    }
    
    # Set XML content type
    response.content_type = 'application/xml; charset=utf-8'
    
    return template('sitemap/index.xml',
                   articles=articles,
                   pages=pages,
                   site_settings=site_settings,
                   today_date=datetime.now().strftime('%Y-%m-%d'),
                   article_route_prefix='articles')
