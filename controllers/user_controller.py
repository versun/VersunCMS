from bottle import route, request, template, redirect
import bcrypt
from models import User

@route('/signup', method='GET')
def signup_form():
    """Display the user registration form."""
    from models import Page
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    return template('users/new', site_settings={}, navbar_items=navbar_items)

@route('/signup', method='POST')
def do_signup():
    """Process the user registration form."""
    username = request.forms.get('username')
    password = request.forms.get('password')

    if not username or not password:
        return "<p>Username and password are required.</p>"

    # Check if user already exists
    if User.select().where(User.user_name == username).exists():
        return f"<p>User '{username}' already exists.</p>"

    # Hash the password
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    # Create new user
    User.create(
        user_name=username,
        password_digest=hashed_password.decode('utf-8')
    )

    return redirect('/login')

@route('/users/<user_id>/edit', method='GET')
def edit_user_form(user_id):
    """Display the user account edit form."""
    try:
        user = User.get(User.id == user_id)
        navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
        return template('users/edit', user=user, site_settings={}, navbar_items=navbar_items)
    except User.DoesNotExist:
        return "<p>User not found.</p>", 404

@route('/users/<user_id>', method='PUT')
def update_user(user_id):
    """Process the user account update form."""
    try:
        user = User.get(User.id == user_id)
        
        # Update username if provided
        new_username = request.forms.get('user_name')
        if new_username and new_username != user.user_name:
            # Check if username already exists
            if User.select().where((User.user_name == new_username) & (User.id != user.id)).exists():
                navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
                return template('users/edit', 
                               user=user,
                               alert="Username already exists",
                               site_settings={},
                               navbar_items=navbar_items)
            user.user_name = new_username
        
        # Update password if provided
        new_password = request.forms.get('password')
        password_confirmation = request.forms.get('password_confirmation')
        
        if new_password:
            if new_password != password_confirmation:
                navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
                return template('users/edit',
                               user=user,
                               alert="Passwords don't match",
                               site_settings={},
                               navbar_items=navbar_items)
            
            # Hash and update password
            hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())
            user.password_digest = hashed_password.decode('utf-8')
        
        user.save()
        
        navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
        return template('users/edit',
                       user=user,
                       notice="Account updated successfully",
                       site_settings={},
                       navbar_items=navbar_items)
        
    except User.DoesNotExist:
        return "<p>User not found.</p>"

@route('/logout', method='POST')
def logout():
    """Process user logout."""
    # In a real app, we would clear the session cookie here
    # For now, just redirect to the home page
    return redirect('/')
