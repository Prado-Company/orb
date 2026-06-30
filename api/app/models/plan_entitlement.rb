class PlanEntitlement < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :organization, optional: true

  validates :plan, :feature, :period, :origin, :valid_from, :subscription_state, presence: true
end
