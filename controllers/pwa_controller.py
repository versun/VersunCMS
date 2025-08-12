from bottle import route, response, template

@route('/manifest.json')
def manifest():
    """Generate PWA manifest.json."""
    response.content_type = 'application/json; charset=utf-8'
    return template('pwa/manifest.json')

@route('/service-worker.js')
def service_worker():
    """Serve the service worker script."""
    response.content_type = 'application/javascript; charset=utf-8'
    return template('pwa/service-worker.js')
