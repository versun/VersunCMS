from bottle import route, request, template, redirect
from models import Page
import json
import os

@route('/admin/settings', method='GET')
def edit_settings():
    """Display the settings edit form."""
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    
    # Mock timezone options
    timezone_options = [
        ('UTC', 'UTC'),
        ('America/New_York', 'America/New_York'),
        ('America/Los_Angeles', 'America/Los_Angeles'),
        ('Europe/London', 'Europe/London'),
        ('Asia/Shanghai', 'Asia/Shanghai'),
    ]
    
    # Mock social platforms
    social_platforms = {
        'mastodon': {'name': 'Mastodon'},
        'twitter': {'name': 'Twitter/X'},
        'bluesky': {'name': 'Bluesky'},
        'github': {'name': 'GitHub'},
    }
    
    # Mock file list
    static_files = []
    static_dir = '/Users/versun/Documents/Projects/versuncms/bottle-version/static'
    if os.path.exists(static_dir):
        static_files = [f for f in os.listdir(static_dir) if os.path.isfile(os.path.join(static_dir, f))]
    
    return template('settings/edit',
                   site_settings={},
                   navbar_items=navbar_items,
                   timezone_options=timezone_options,
                   social_platforms=social_platforms,
                   files=static_files)

@route('/settings', method='PUT') 
def update_settings():
    """Process the settings update form."""
    # In a real app, we would save these settings to database
    title = request.forms.get('title')
    description = request.forms.get('description')
    author = request.forms.get('author')
    url = request.forms.get('url')
    time_zone = request.forms.get('time_zone')
    head_code = request.forms.get('head_code')
    giscus = request.forms.get('giscus')
    tool_code = request.forms.get('tool_code')
    footer = request.forms.get('footer')
    custom_css = request.forms.get('custom_css')
    
    # Social links processing
    social_links = {}
    for platform in ['mastodon', 'twitter', 'bluesky', 'github']:
        url_key = f'social_links[{platform}][url]'
        if url_key in request.forms:
            social_links[platform] = {'url': request.forms.get(url_key)}
    
    # In a real app, save to database
    print(f"Updating settings: {title}, {description}, etc.")
    
    return redirect('/admin/settings?message=Settings updated')

@route('/settings/upload', method='POST')
def upload_file():
    """Handle file upload."""
    upload = request.files.get('file')
    if upload:
        # In a real app, we would handle file upload properly
        filename = upload.filename
        print(f"Uploading file: {filename}")
        
    return redirect('/admin/settings?message=File uploaded')

@route('/settings', method='DELETE')
def delete_file():
    """Handle file deletion."""
    filename = request.forms.get('filename')
    if filename:
        # In a real app, we would delete the file
        print(f"Deleting file: {filename}")
        
    return redirect('/admin/settings?message=File deleted')
