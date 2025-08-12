from bottle import route, template
from models import Page
import random
from datetime import datetime, timedelta

@route('/admin/analytics', method='GET')
def analytics_dashboard():
    """Display the analytics dashboard."""
    navbar_items = Page.select().where(Page.status == 'publish').order_by(Page.page_order)
    
    # Mock analytics data for demonstration
    mock_analytics = {
        'total_visits': random.randint(1000, 5000),
        'unique_visitors': random.randint(500, 2000),
        'page_views': random.randint(2000, 8000),
        'bounce_rate': random.randint(30, 70),
        'avg_session_duration': f"{random.randint(2, 8)}:{random.randint(10, 59):02d}",
        
        # Top pages
        'top_pages': [
            {'path': '/', 'views': random.randint(100, 500), 'visitors': random.randint(50, 200)},
            {'path': '/articles/sample-post', 'views': random.randint(50, 300), 'visitors': random.randint(30, 150)},
            {'path': '/pages/about', 'views': random.randint(20, 100), 'visitors': random.randint(15, 80)},
        ],
        
        # Traffic sources
        'traffic_sources': [
            {'source': 'Direct', 'visits': random.randint(200, 800), 'percentage': random.randint(30, 50)},
            {'source': 'Search Engines', 'visits': random.randint(100, 400), 'percentage': random.randint(20, 35)},
            {'source': 'Social Media', 'visits': random.randint(50, 200), 'percentage': random.randint(10, 25)},
            {'source': 'Referrals', 'visits': random.randint(30, 150), 'percentage': random.randint(5, 15)},
        ],
        
        # Browsers
        'browsers': [
            {'name': 'Chrome', 'visits': random.randint(300, 1200), 'percentage': random.randint(40, 60)},
            {'name': 'Safari', 'visits': random.randint(100, 500), 'percentage': random.randint(15, 30)},
            {'name': 'Firefox', 'visits': random.randint(50, 300), 'percentage': random.randint(10, 20)},
            {'name': 'Edge', 'visits': random.randint(30, 200), 'percentage': random.randint(5, 15)},
        ],
        
        # Operating systems
        'operating_systems': [
            {'name': 'Windows', 'visits': random.randint(200, 800), 'percentage': random.randint(35, 55)},
            {'name': 'macOS', 'visits': random.randint(150, 600), 'percentage': random.randint(25, 40)},
            {'name': 'Linux', 'visits': random.randint(50, 200), 'percentage': random.randint(8, 18)},
            {'name': 'Mobile', 'visits': random.randint(100, 400), 'percentage': random.randint(15, 25)},
        ],
        
        # Devices
        'devices': [
            {'type': 'Desktop', 'visits': random.randint(400, 1500), 'percentage': random.randint(50, 70)},
            {'type': 'Mobile', 'visits': random.randint(200, 800), 'percentage': random.randint(25, 40)},
            {'type': 'Tablet', 'visits': random.randint(50, 300), 'percentage': random.randint(5, 15)},
        ]
    }
    
    return template('analytics/index',
                   analytics=mock_analytics,
                   total_visits=mock_analytics['total_visits'],
                   visits_by_path=mock_analytics.get('top_pages', {}),
                   referrers=mock_analytics.get('referrers', {}),
                   site_settings={},
                   navbar_items=navbar_items)
