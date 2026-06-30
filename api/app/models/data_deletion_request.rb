class DataDeletionRequest < ApplicationRecord
  belongs_to :user

  validates :status, :requested_at, :soft_deleted_at, :hard_delete_scheduled_at, :source, presence: true
end
