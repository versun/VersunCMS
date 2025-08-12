from bottle import route, request, template, redirect
from models import Page
import markdown2

@route('/pages', method='GET')
def list_pages():
    """Display a list of all pages."""
    pages = Page.select().order_by(Page.page_order)
    output = '<h1>Pages</h1><ul>'
    for page in pages:
        output += f'<li><a href="/pages/{page.slug}">{page.title}</a></li>'
    output += '</ul><a href="/pages/new">New Page</a>'
    return output

@route('/pages/new', method='GET')
def new_page_form():
    """Display the form to create a new page."""
    # The 'page' object is needed by the form template.
    # We can pass a dummy object for now.
    class DummyPage:
        pass
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('page_new', page=DummyPage(), site_settings={}, navbar_items=navbar_items)

@route('/pages/new', method='POST')
def do_new_page():
    """Process the new page form."""
    slug = request.forms.get('slug').lower().strip().replace(' ', '-')
    Page.create(
        title=request.forms.get('title'),
        slug=slug,
        content=request.forms.get('content'),
        page_order=int(request.forms.get('page_order')),
        status=int(request.forms.get('status'))
    )
    return redirect('/pages')

@route('/pages/<slug>', method='GET')
def show_page(slug):
    """Display a single page."""
    try:
        page = Page.get(Page.slug == slug)
        navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
        return template('page_show', page=page, site_settings={}, markdown2=markdown2, navbar_items=navbar_items)
    except Page.DoesNotExist:
        return "<p>Page not found.</p>", 404

@route('/pages/<slug>/edit', method='GET')
def edit_page_form(slug):
    """Display the form to edit an existing page."""
    try:
        page = Page.get(Page.slug == slug)
        navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
        return template('pages/edit', page=page, site_settings={}, navbar_items=navbar_items)
    except Page.DoesNotExist:
        return "<p>Page not found.</p>", 404

@route('/pages/<slug>/edit', method='POST')
def update_page(slug):
    """Process the edit page form."""
    try:
        page = Page.get(Page.slug == slug)
        page.title = request.forms.get('title')
        page.slug = request.forms.get('slug').lower().strip().replace(' ', '-')
        page.content = request.forms.get('content')
        page.page_order = int(request.forms.get('page_order', 0))
        page.status = request.forms.get('status')
        page.redirect_url = request.forms.get('redirect_url', '')
        page.save()
        
        return redirect(f'/pages/{page.slug}')
    except Page.DoesNotExist:
        return "<p>Page not found.</p>", 404

