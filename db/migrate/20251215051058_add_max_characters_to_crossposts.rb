class AddMaxCharactersToCrossposts < ActiveRecord::Migration[8.1]
  def change
    add_column :crossposts, :max_characters, :integer
    
    # 为现有记录设置默认值
    reversible do |dir|
      dir.up do
        # Mastodon 默认 500 字符
        execute <<-SQL
          UPDATE crossposts SET max_characters = 500 WHERE platform = 'mastodon' AND max_characters IS NULL;
        SQL
        # Twitter 默认 250 字符（考虑非ASCII字符计为2）
        execute <<-SQL
          UPDATE crossposts SET max_characters = 250 WHERE platform = 'twitter' AND max_characters IS NULL;
        SQL
        # Bluesky 默认 300 字符
        execute <<-SQL
          UPDATE crossposts SET max_characters = 300 WHERE platform = 'bluesky' AND max_characters IS NULL;
        SQL
        # Internet Archive 不需要字符限制，设置为 NULL
      end
    end
  end
end
