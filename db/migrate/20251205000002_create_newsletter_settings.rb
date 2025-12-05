class CreateNewsletterSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :newsletter_settings do |t|
      t.string :provider, default: "native", null: false
      t.boolean :enabled, default: false, null: false
      t.string :smtp_address
      t.integer :smtp_port, default: 587
      t.string :smtp_user_name
      t.string :smtp_password
      t.string :smtp_domain
      t.string :smtp_authentication, default: "plain"
      t.boolean :smtp_enable_starttls, default: true
      t.string :from_email

      t.timestamps
    end
  end
end

