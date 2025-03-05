module ApplicationHelper
  def site_settings
    Setting.site_info
  end
end
