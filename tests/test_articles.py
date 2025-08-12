import pytest
from peewee import SqliteDatabase
from models import Article, User, Page, Setting, Crosspost, SocialMediaPost, ActivityLog

# A list of all models for easier setup and teardown
MODELS = [User, Article, Page, Setting, Crosspost, SocialMediaPost, ActivityLog]

@pytest.fixture
def test_db():
    """Fixture to set up an in-memory SQLite database for tests."""
    db = SqliteDatabase(':memory:')
    db.bind(MODELS, bind_refs=False, bind_backrefs=False)
    db.connect()
    db.create_tables(MODELS)
    yield db
    db.close()


def test_article_creation(test_db):
    """Test that an article can be created in the database."""
    # Given: An empty database
    assert Article.select().count() == 0

    # When: An article is created
    Article.create(
        title="My First Test Article",
        slug="my-first-test-article",
        description="A short description.",
        content="# Hello Test\n\nThis is a test.",
        status=1
    )

    # Then: The article should exist in the database
    assert Article.select().count() == 1
    article = Article.get(Article.slug == "my-first-test-article")
    assert article.title == "My First Test Article"
    assert article.content == "# Hello Test\n\nThis is a test."
