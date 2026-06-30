class Energy < ApplicationRecord
  belongs_to :user

  STATES = %w[alta media baixa em_recuperacao em_sobrecarga].freeze

  validates :value, :qualitative_state, :calibration_source, :confidence, :measured_at, :source, presence: true
  validates :value, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :qualitative_state, inclusion: { in: STATES }
end
