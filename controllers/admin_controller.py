from bottle import route, template, request, redirect
from models import Article, Page

@route('/admin', method='GET')
def admin_dashboard():
    """Display the main admin dashboard."""
    # Redirect to the posts page, which is the main admin view for now.
    redirect('/admin/posts')

@route('/admin/posts', method='GET')
def admin_posts():
    """Display a list of all articles for admin."""
    # Status mapping: string to integer
    STATUS_MAP = {
        'draft': 0,
        'published': 1,
        'schedule': 2
    }
    
    status_str = request.query.status or 'published'
    status_int = STATUS_MAP.get(status_str, 1)  # Default to published
    
    articles = Article.select().where(Article.status == status_int).order_by(Article.created_at.desc())
    navbar_items = Page.select().where(Page.status == 1).order_by(Page.page_order)

    status_counts = {
        'published': Article.select().where(Article.status == 1).count(),
        'draft': Article.select().where(Article.status == 0).count(),
        'schedule': Article.select().where(Article.status == 2).count(),
    }

    return template('admin/posts', articles=articles, site_settings={}, status_counts=status_counts, current_status=status_str, navbar_items=navbar_items)

@route('/admin/pages', method='GET')
def admin_pages():
    """Display a list of all pages for admin."""
    pages = Page.select()
    navbar_items = Page.select().where(Page.status == 1).order_by(Page.page_order)
    # Add missing variables for the template
    current_status = 'published'  # Default status
    status = 'published'
    return template('admin/pages', pages=pages, site_settings={}, navbar_items=navbar_items, 
                   current_status=current_status, status=status)
