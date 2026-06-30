class Task < ApplicationRecord
  belongs_to :user
  belongs_to :organization, optional: true

  STATUSES = %w[nao_iniciado em_progresso concluido adiado].freeze
  WEIGHTS = %w[leve medio pesado].freeze
  ORIGINS = %w[user orb integration].freeze

  validates :title, :status, :origin, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :weight, inclusion: { in: WEIGHTS }, allow_blank: true
  validates :origin, inclusion: { in: ORIGINS }

  scope :active, -> { where(deleted_at: nil) }

  def privacy_level
    context.present? ? "sensivel" : "interno"
  end
end
