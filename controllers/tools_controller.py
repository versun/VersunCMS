from bottle import route, request, template, redirect, response
from models import Page, Article
import json
import csv
from datetime import datetime
from io import StringIO

@route('/admin/tools/export', method='GET')
def export_tools():
    """Display the export tools page."""
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('tools/export/index',
                   site_settings={},
                   navbar_items=navbar_items)

@route('/tools/export', method='POST')
def do_export():
    """Handle data export."""
    # Export articles to CSV
    articles = Article.select()
    
    # Create CSV content
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(['ID', 'Title', 'Slug', 'Description', 'Content', 'Status', 'Created At', 'Updated At'])
    
    for article in articles:
        writer.writerow([
            article.id,
            article.title,
            article.slug,
            article.description,
            article.content,
            article.status,
            article.created_at,
            article.updated_at
        ])
    
    # Set response headers for CSV download
    response.content_type = 'text/csv; charset=utf-8'
    response.headers['Content-Disposition'] = f'attachment; filename="articles_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv"'
    
    return output.getvalue()

@route('/admin/tools/import', method='GET')
def import_tools():
    """Display the import tools page."""
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    
    # Mock activity logs for demonstration
    mock_activity_logs = [
        {
            'created_at': datetime.now(),
            'level': 'info',
            'description': 'Successfully imported 5 articles from RSS feed'
        },
        {
            'created_at': datetime.now(),
            'level': 'warn',
            'description': 'Duplicate article found, skipped import'
        },
        {
            'created_at': datetime.now(),
            'level': 'error',
            'description': 'Failed to download image from URL'
        }
    ]
    
    return template('tools/import/index',
                   activity_logs=mock_activity_logs,
                   site_settings={},
                   navbar_items=navbar_items)

@route('/tools/import/from_rss', method='POST')
def import_from_rss():
    """Handle RSS import."""
    rss_url = request.forms.get('url')
    import_images = request.forms.get('import_images') == '1'
    
    # In a real app, we would process the RSS feed
    # For now, just simulate the import
    print(f"Importing from RSS: {rss_url}, Import images: {import_images}")
    
    # Simulate processing delay and redirect back with success message
    return redirect('/admin/tools/import?message=RSS import initiated')
