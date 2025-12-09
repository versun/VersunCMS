class AddCommentableToComments < ActiveRecord::Migration[8.1]
  def change
    # Add polymorphic association columns
    add_column :comments, :commentable_type, :string
    add_column :comments, :commentable_id, :integer
    
    # Migrate existing data: set commentable to Article for all existing comments
    execute <<-SQL
      UPDATE comments 
      SET commentable_type = 'Article', commentable_id = article_id 
      WHERE article_id IS NOT NULL
    SQL
    
    # Add index for polymorphic association
    add_index :comments, [:commentable_type, :commentable_id]
    
    # Make article_id nullable (we'll keep it for backward compatibility during transition)
    change_column_null :comments, :article_id, true
  end
end
