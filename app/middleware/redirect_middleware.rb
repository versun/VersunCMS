class RedirectMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    path = request.path

    # Skip redirects for admin pages, assets, and API endpoints
    return @app.call(env) if path.start_with?("/admin", "/assets", "/rails", "/up")

    # Check all redirects
    redirect = find_matching_redirect(path)
    if redirect
      target_url = redirect.apply_to(path)
      if target_url
        Rails.event.notify "middleware.redirect.applied",
          level: "info",
          component: "redirect_middleware",
          from_path: path,
          to_url: target_url,
          status_code: redirect.permanent? ? 301 : 302,
          permanent: redirect.permanent?
        status = redirect.permanent? ? 301 : 302
        return [ status, { "Location" => target_url, "Content-Type" => "text/html" }, [] ]
      end
    end

    @app.call(env)
  end

  private

  def find_matching_redirect(path)
    # Use all redirects and filter by enabled? method to handle string/boolean values
    Redirect.all.find do |redirect|
      next unless redirect.enabled?
      redirect.match?(path)
    end
  end
end
