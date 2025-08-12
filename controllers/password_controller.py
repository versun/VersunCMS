from bottle import route, request, template, redirect
import bcrypt
from models import User, Page

@route('/passwords/new', method='GET')
def forgot_password_form():
    """Display the forgot password form."""
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('passwords/new', site_settings={}, navbar_items=navbar_items)

@route('/passwords', method='POST')
def send_password_reset():
    """Process the forgot password form."""
    user_name = request.forms.get('user_name')
    
    try:
        user = User.get(User.user_name == user_name)
        # In a real app, we would generate a reset token and send an email
        # For now, just redirect with a message
        return redirect('/passwords/new?message=Reset instructions sent')
    except User.DoesNotExist:
        return template('passwords/new', 
                       alert="User not found", 
                       site_settings={}, 
                       navbar_items=Page.select().where(Page.status == 'publish').order_by(Page.page_order))

@route('/passwords/<token>/edit', method='GET')
def edit_password_form(token):
    """Display the password reset form."""
    # In a real app, we would validate the token
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('passwords/edit', site_settings={}, navbar_items=navbar_items, token=token)

@route('/password', method='PUT')
def update_password():
    """Process the password update form."""
    password = request.forms.get('password')
    password_confirmation = request.forms.get('password_confirmation')
    
    if password != password_confirmation:
        navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
        return template('passwords/edit', 
                       alert="Passwords don't match", 
                       site_settings={}, 
                       navbar_items=navbar_items)
    
    # In a real app, we would find the user by token and update their password
    # For now, just redirect to login
    return redirect('/login?message=Password updated')
