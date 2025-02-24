class MigrateClientDataInCrossposts < ActiveRecord::Migration[8.0]
  def up
    Crosspost.find_each do |crosspost|
      case crosspost.platform
      when "mastodon"
        crosspost.update_columns(
          client_key: crosspost.client_id,
          client_id: nil
        )
      when "twitter"
        crosspost.update_columns(
          api_key: crosspost.client_id,
          api_key_secret: crosspost.client_secret,
          client_id: nil,
          client_secret: nil
        )
      when "bluesky"
        crosspost.update_columns(
          username: crosspost.access_token,
          app_password: crosspost.access_token_secret,
          access_token: nil,
          access_token_secret: nil
        )
      end
    end
  end

  def down
    Crosspost.find_each do |crosspost|
      case crosspost.platform
      when "mastodon"
        crosspost.update_columns(
          client_id: crosspost.client_key,
          client_key: nil
        )
      when "twitter"
        crosspost.update_columns(
          client_id: crosspost.api_key,
          client_secret: crosspost.api_key_secret,
          api_key: nil,
          api_key_secret: nil
        )
      when "bluesky"
        crosspost.update_columns(
          access_token: crosspost.username,
          access_token_secret: crosspost.app_password,
          username: nil,
          app_password: nil
        )
      end
    end
  end
end