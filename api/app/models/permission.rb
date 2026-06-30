class Permission < ApplicationRecord
  belongs_to :actor, class_name: "User"
  belongs_to :granted_by, class_name: "User", optional: true

  validates :role, :scope, :resource, :valid_from, presence: true
end
