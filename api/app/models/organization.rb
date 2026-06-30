class Organization < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :organization_memberships, dependent: :destroy

  validates :name, :plan, :status, presence: true
end
