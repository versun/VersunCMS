from bottle import route, request, template, redirect
import markdown2
from models import Article, Page

@route('/articles', method='GET')
def list_articles():
    """Display a list of all articles."""
    articles = Article.select()
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('articles', articles=articles, site_settings={}, markdown2=markdown2, navbar_items=navbar_items)

@route('/articles', method='POST')
def create_article():
    """Process the new article form."""
    from datetime import datetime
    import re
    
    # Status mapping: string to integer
    STATUS_MAP = {
        'draft': 0,
        'published': 1,
        'schedule': 2
    }
    
    # Get form data
    title = request.forms.get('title')
    slug = request.forms.get('slug')
    description = request.forms.get('description')
    content = request.forms.get('content')
    status_str = request.forms.get('status')
    
    # Simple validation
    if not title or not content or not status_str:
        # Return to form with errors
        navbar_items = Page.select().where(Page.status == 1).order_by(Page.page_order)  # 1 = published
        
        class DummyArticle:
            def __init__(self):
                self.id = None
                self.title = title or ''
                self.slug = slug or ''
                self.description = description or ''
                self.content = content or ''
                self.status = status_str or 'draft'
                self.scheduled_at = None
                self.created_at = None
                self.crosspost_mastodon = False
                self.crosspost_twitter = False
                self.crosspost_bluesky = False
                self.send_newsletter = False
                self.social_media_posts = {}
        
        article = DummyArticle()
        errors = []
        if not title:
            errors.append("Title is required")
        if not content:
            errors.append("Content is required")
        if not status_str:
            errors.append("Status is required")
            
        crossposts = []
        newsletter_enabled = False
        current_time = datetime.now()
        
        return template('articles/new', article=article, site_settings={}, navbar_items=navbar_items,
                       crossposts=crossposts, newsletter_enabled=newsletter_enabled, current_time=current_time,
                       errors=errors)
    
    # Convert status string to integer
    status_int = STATUS_MAP.get(status_str)
    if status_int is None:
        # Invalid status
        navbar_items = Page.select().where(Page.status == 1).order_by(Page.page_order)
        
        class DummyArticle:
            def __init__(self):
                self.id = None
                self.title = title or ''
                self.slug = slug or ''
                self.description = description or ''
                self.content = content or ''
                self.status = status_str or 'draft'
                self.scheduled_at = None
                self.created_at = None
                self.crosspost_mastodon = False
                self.crosspost_twitter = False
                self.crosspost_bluesky = False
                self.send_newsletter = False
                self.social_media_posts = {}
        
        article = DummyArticle()
        errors = [f"Invalid status: {status_str}"]
        crossposts = []
        newsletter_enabled = False
        current_time = datetime.now()
        
        return template('articles/new', article=article, site_settings={}, navbar_items=navbar_items,
                       crossposts=crossposts, newsletter_enabled=newsletter_enabled, current_time=current_time,
                       errors=errors)
    
    try:
        # Generate slug if not provided
        if not slug:
            slug = re.sub(r'[^a-zA-Z0-9\s-]', '', title.lower())
            slug = re.sub(r'\s+', '-', slug.strip())
        
        # Ensure slug is unique
        original_slug = slug
        counter = 1
        while True:
            try:
                # Check if slug already exists
                existing = Article.select().where(Article.slug == slug).first()
                if not existing:
                    break
                # If exists, append counter
                slug = f"{original_slug}-{counter}"
                counter += 1
            except:
                # If there's an error checking, break and try to create
                break
        
        # Create the article
        article = Article.create(
            title=title,
            slug=slug,
            description=description or '',
            content=content,
            status=status_int,
            created_at=datetime.now()
        )
        
        # Redirect to the article or articles list
        if status_str == 'published':
            return redirect(f'/articles/{article.slug}')
        else:
            return redirect('/articles')
            
    except Exception as e:
        # Skip HTTPResponse exceptions (these are normal redirects)
        from bottle import HTTPResponse
        if isinstance(e, HTTPResponse):
            raise e
        # Handle database errors with detailed error message
        import traceback
        error_details = str(e)
        print(f"Database error creating article: {error_details}")
        print(f"Traceback: {traceback.format_exc()}")
        
        navbar_items = Page.select().where(Page.status == 1).order_by(Page.page_order)
        
        class DummyArticle:
            def __init__(self):
                self.id = None
                self.title = title or ''
                self.slug = slug or ''
                self.description = description or ''
                self.content = content or ''
                self.status = status_str or 'draft'
                self.scheduled_at = None
                self.created_at = None
                self.crosspost_mastodon = False
                self.crosspost_twitter = False
                self.crosspost_bluesky = False
                self.send_newsletter = False
                self.social_media_posts = {}
        
        article = DummyArticle()
        errors = [f"Error creating article: {error_details}"]
        crossposts = []
        newsletter_enabled = False
        current_time = datetime.now()
        
        return template('articles/new', article=article, site_settings={}, navbar_items=navbar_items,
                       crossposts=crossposts, newsletter_enabled=newsletter_enabled, current_time=current_time,
                       errors=errors)

@route('/articles/new', method='GET')
def new_article_form():
    """Display the form to create a new article."""
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    # Create a dummy article object for the form
    class DummyArticle:
        def __init__(self):
            self.id = None  # 新文章没有ID
            self.title = ''
            self.slug = ''
            self.description = ''
            self.content = ''
            self.status = 'draft'
            self.scheduled_at = None
            self.created_at = None
            self.crosspost_mastodon = False
            self.crosspost_twitter = False
            self.crosspost_bluesky = False
            self.send_newsletter = False
            self.social_media_posts = {}
    
    article = DummyArticle()
    # Add missing variables for the template
    crossposts = []
    newsletter_enabled = False
    from datetime import datetime
    current_time = datetime.now()
    
    return template('articles/new', article=article, site_settings={}, navbar_items=navbar_items, 
                   crossposts=crossposts, newsletter_enabled=newsletter_enabled, current_time=current_time)

@route('/articles/<slug>/edit', method='GET')
def edit_article_form(slug):
    """Display the form to edit an existing article."""
    from datetime import datetime
    try:
        article = Article.get(Article.slug == slug)
        navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
        
        # Add missing variables for the template
        crossposts = []  # Empty list for now, can be populated with existing crosspost data
        newsletter_enabled = False  # Can be configured based on your newsletter settings
        current_time = datetime.now()
        
        return template('articles/edit', article=article, site_settings={}, navbar_items=navbar_items,
                       crossposts=crossposts, newsletter_enabled=newsletter_enabled, current_time=current_time)
    except Article.DoesNotExist:
        return "<p>Article not found.</p>", 404

@route('/articles/<slug>/edit', method='POST')
def update_article(slug):
    """Process the edit article form."""
    try:
        article = Article.get(Article.slug == slug)
        article.title = request.forms.get('title')
        article.slug = request.forms.get('slug').lower().strip().replace(' ', '-')
        article.description = request.forms.get('description')
        article.content = request.forms.get('content')
        article.status = request.forms.get('status')
        article.save()

        # Check if we need to crosspost
        if request.forms.get('crosspost'):
            print(f"Enqueuing crosspost task for article {article.id}")
            from tasks import crosspost_article
            crosspost_article(article.id)

        return redirect(f'/articles/{article.slug}')
    except Article.DoesNotExist:
        return "<p>Article not found.</p>", 404

@route('/articles/<slug>', method='GET')
def show_article(slug):
    """Display a single article by slug."""
    try:
        article = Article.get(Article.slug == slug)
        navbar_items = Page.select().where(Page.status == 1).order_by(Page.page_order)  # 1 = published
        return template('articles/show', article=article, site_settings={}, navbar_items=navbar_items, markdown2=markdown2)
    except Article.DoesNotExist:
        return "<p>Article not found.</p>", 404
