class Suggestion < ApplicationRecord
  belongs_to :user

  validates :source, :privacy_level, presence: true
end
