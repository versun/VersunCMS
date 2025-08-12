import datetime
from peewee import Model, CharField, TextField, IntegerField, DateTimeField, BooleanField, ForeignKeyField
from database import db

class BaseModel(Model):
    class Meta:
        database = db

class User(BaseModel):
    user_name = CharField(unique=True, null=False)
    password_digest = CharField(null=False)
    created_at = DateTimeField(default=datetime.datetime.now)
    updated_at = DateTimeField(default=datetime.datetime.now)

class Article(BaseModel):
    title = CharField()
    slug = CharField(unique=True)
    description = TextField(null=True)
    content = TextField(null=True)
    status = IntegerField(null=False)
    scheduled_at = DateTimeField(null=True)
    crosspost_mastodon = BooleanField(default=False, null=False)
    crosspost_twitter = BooleanField(default=False, null=False)
    crosspost_bluesky = BooleanField(default=False, null=False)
    send_newsletter = BooleanField(default=False, null=False)
    # ActionText body will be handled separately
    created_at = DateTimeField(default=datetime.datetime.now)
    updated_at = DateTimeField(default=datetime.datetime.now)

class Page(BaseModel):
    title = CharField()
    slug = CharField(unique=True)
    status = IntegerField(null=False)
    content = TextField(null=True)
    page_order = IntegerField(default=0, null=False)
    redirect_url = CharField(null=True)
    # ActionText body will be handled separately
    created_at = DateTimeField(default=datetime.datetime.now)
    updated_at = DateTimeField(default=datetime.datetime.now)

class Setting(BaseModel):
    title = CharField(null=True)
    description = TextField(null=True)
    author = CharField(null=True)
    url = CharField(null=True)
    time_zone = CharField(default='UTC')
    head_code = TextField(null=True)
    tool_code = TextField(null=True)
    custom_css = TextField(null=True)
    giscus = TextField(null=True)
    social_links = TextField(null=True) # Stored as JSON string

class Crosspost(BaseModel):
    platform = CharField(null=False, unique=True)
    enabled = BooleanField(default=False, null=False)
    # Storing credentials directly is not ideal, but for a 1:1 migration we'll keep it simple.
    # In a real-world scenario, use encrypted credentials or a proper secrets manager.
    settings = TextField(null=True) # A flexible field for various platform settings, stored as JSON string

class SocialMediaPost(BaseModel):
    platform = CharField(null=False)
    url = CharField(null=False)
    article = ForeignKeyField(Article, backref='social_media_posts')
    created_at = DateTimeField(default=datetime.datetime.now)

class ActivityLog(BaseModel):
    action = CharField()
    target = CharField(null=True)
    description = TextField(null=True)
    level = IntegerField(default=0) # e.g., 0: info, 1: warn, 2: error
    created_at = DateTimeField(default=datetime.datetime.now)

def create_tables():
    """Create database tables for all models."""
    with db:
        db.create_tables([User, Article, Page, Setting, Crosspost, SocialMediaPost, ActivityLog])

if __name__ == '__main__':
    print("Creating database tables...")
    create_tables()
    print("Tables created successfully.")
