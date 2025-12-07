class AddCommentFetchScheduleToCrossposts < ActiveRecord::Migration[8.1]
  def up
    add_column :crossposts, :comment_fetch_schedule, :string
    
    # Convert existing auto_fetch_comments to weekly schedule if enabled
    Crosspost.find_each do |crosspost|
      if crosspost.auto_fetch_comments
        crosspost.update_column(:comment_fetch_schedule, 'weekly')
      end
    end
  end

  def down
    # Clear all schedule values before removing column
    Crosspost.find_each do |crosspost|
      if crosspost.comment_fetch_schedule.present?
        crosspost.update_column(:comment_fetch_schedule, nil)
      end
    end
    
    remove_column :crossposts, :comment_fetch_schedule
  end
end


