import pytest
from models import Page
from tests.test_articles import test_db # Reuse the same db fixture

def test_page_creation(test_db):
    """Test that a page can be created in the database."""
    # Given: An empty database
    assert Page.select().count() == 0

    # When: A page is created
    Page.create(
        title="About Us",
        slug="about-us",
        content="This is the about page.",
        status=1,
        page_order=1
    )

    # Then: The page should exist in the database
    assert Page.select().count() == 1
    page = Page.get(Page.slug == "about-us")
    assert page.title == "About Us"
    assert page.page_order == 1
