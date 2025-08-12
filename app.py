from bottle import route, run, template, request, redirect
import bcrypt
import markdown2
from models import User, Article, Crosspost, Page
from tasks import crosspost_article

# Import controllers
from controllers import (
    user_controller, 
    article_controller, 
    page_controller, 
    crosspost_controller, 
    admin_controller, 
    newsletter_controller,
    password_controller,
    settings_controller,
    analytics_controller,
    tools_controller,
    sitemap_controller,
    pwa_controller
)

@route('/')
def index():
    """Display the homepage with a list of published articles."""
    articles = Article.select().where(Article.status == 1).order_by(Article.created_at.desc())
    navbar_items = Page.select().where(Page.status == 1).order_by(Page.page_order)
    return template('articles/index', articles=articles, site_settings={}, markdown2=markdown2, navbar_items=navbar_items)

@route('/login', method='GET')
def login_form():
    """Display the login form."""
    from models import Page
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('sessions/new', site_settings={}, navbar_items=navbar_items)

@route('/login', method='POST')
def do_login():
    """Process the login form."""
    username = request.forms.get('username')
    password = request.forms.get('password')

    try:
        user = User.get(User.user_name == username)
    except User.DoesNotExist:
        return "<p>Login failed. User not found.</p>"

    if bcrypt.checkpw(password.encode('utf-8'), user.password_digest.encode('utf-8')):
        # In a real app, we would set a session cookie here.
        return f"<p>Welcome, {user.user_name}!</p>"
    else:
        return "<p>Login failed. Incorrect password.</p>"

@route('/articles/new', method='POST')
def do_new_article():
    """Process the new article form."""
    # A simple slugify function
    slug = request.forms.get('slug').lower().strip().replace(' ', '-')
    article = Article.create(
        title=request.forms.get('title'),
        slug=slug,
        description=request.forms.get('description'),
        content=request.forms.get('content'),
        status=int(request.forms.get('status'))
    )

    # Check if we need to crosspost
    if request.forms.get('crosspost'):
        print(f"Enqueuing crosspost task for article {article.id}")
        crosspost_article(article.id)

    return redirect('/articles')

@route('/articles/<slug>', method='GET')
def show_article(slug):
    """Display a single article."""
    try:
        article = Article.get(Article.slug == slug)
        navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
        return template('article_show', article=article, site_settings={}, markdown2=markdown2, navbar_items=navbar_items)
    except Article.DoesNotExist:
        return "<p>Article not found.</p>", 404


if __name__ == '__main__':
    # The reloader will handle server restarts
    run(host='localhost', port=8080, debug=True, reloader=True)


