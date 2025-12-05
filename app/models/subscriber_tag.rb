class SubscriberTag < ApplicationRecord
  belongs_to :subscriber
  belongs_to :tag

  validates :subscriber_id, uniqueness: { scope: :tag_id }
end

