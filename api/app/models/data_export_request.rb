class DataExportRequest < ApplicationRecord
  belongs_to :user

  validates :status, :requested_at, :source, presence: true
end
