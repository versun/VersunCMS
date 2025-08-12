from bottle import route, request, template, redirect
from models import Crosspost, Page
import json

@route('/admin/crossposts', method='GET')
def list_crossposts():
    """Display a list of all crosspost configurations."""
    configs = Crosspost.select()
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('crossposts/index', configs=configs, site_settings={}, navbar_items=navbar_items)

@route('/admin/crossposts/new', method='GET')
def new_crosspost_form():
    """Display the form to create a new crosspost configuration."""
    # For now, we'll use a simple form for Mastodon as an example.
    return '''
        <form action="/admin/crossposts/new" method="post">
            <h3>Add Mastodon Configuration</h3>
            Platform: <input name="platform" type="text" value="mastodon" readonly /><br>
            Server URL: <input name="server_url" type="text" placeholder="e.g., https://mastodon.social" /><br>
            Client Key: <input name="client_key" type="text" /><br>
            Client Secret: <input name="client_secret" type="password" /><br>
            Access Token: <input name="access_token" type="password" /><br>
            Enabled: <input name="enabled" type="checkbox" value="true" /><br>
            <input value="Save" type="submit" />
        </form>
    '''

@route('/admin/crossposts', method='POST')
def do_new_crosspost():
    """Process the new crosspost configuration form."""
    platform = request.forms.get('platform')
    settings = {
        'server_url': request.forms.get('server_url'),
        'client_key': request.forms.get('client_key'),
        'client_secret': request.forms.get('client_secret'),
        'access_token': request.forms.get('access_token'),
    }

    Crosspost.create(
        platform=platform,
        enabled=bool(request.forms.get('enabled')),
        settings=json.dumps(settings) # Store settings as a JSON string
    )
    return redirect('/admin/crossposts')

@route('/admin/crossposts/<id>/edit', method='GET')
def edit_crosspost_form(id):
    return "Not implemented yet"

@route('/admin/crossposts/<id>', method='POST')
def do_update_crosspost(id):
    return "Not implemented yet"

@route('/admin/crossposts/<id>/delete', method='POST')
def do_delete_crosspost(id):
    """Delete a crosspost configuration."""
    # Implementation would go here
    return redirect('/admin/crossposts')

@route('/crossposts/mastodon', method='POST')
def update_mastodon_crosspost():
    """Update Mastodon crosspost configuration."""
    platform = request.forms.get('platform', 'mastodon')
    enabled = request.forms.get('enabled') == 'on'
    server_url = request.forms.get('server_url', '').strip()
    client_key = request.forms.get('client_key', '').strip()
    client_secret = request.forms.get('client_secret', '').strip()
    access_token = request.forms.get('access_token', '').strip()
    
    # In a real app, we would save/update the crosspost configuration
    # For now, just redirect back to the crosspost settings
    return redirect('/admin/crossposts')
