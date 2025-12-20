class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  normalizes :user_name, with: ->(e) { e.strip.downcase }

  validates :user_name, presence: true, uniqueness: true
end
