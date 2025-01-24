# config/initializers/action_text_rich_text.rb
ActiveSupport.on_load :action_text_rich_text do
  include PgSearch::Model
  multisearchable against: :body
end
