class OrganizationMembership < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  validates :role, :status, presence: true
end
