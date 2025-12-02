class AddSetupCompletedToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :setup_completed, :boolean, default: false

    # For existing installations with users, mark setup as completed
    reversible do |dir|
      dir.up do
        begin
          if ActiveRecord::Base.connection.table_exists?(:users) &&
            ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM users") > 0
            Setting.update_all(setup_completed: true)
          end
        rescue ActiveRecord::StatementInvalid
          # 忽略表不存在的错误,继续执行迁移
        end
      end
    end
  end
end
