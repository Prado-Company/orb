class EnergeticProfile < ApplicationRecord
  NEURODIVERGENT_IDENTIFICATIONS = %w[
    tdah
    autismo
    tea_autismo
    ahsd
    dislexia
    burnout
    outras_condicoes_neurodivergentes
    ainda_investigando
    nao_sei_tenho_duvidas
    nao_possuo
    prefiro_nao_dizer
  ].freeze
  MUTUALLY_EXCLUSIVE_IDENTIFICATIONS = %w[nao_possuo prefiro_nao_dizer].freeze

  belongs_to :user

  validates :archetype, :main_goal, :preferred_tone, :sensitivity,
            :notification_intensity, :first_check_in_time, :last_check_in_time,
            :confidence, :source, presence: true
  validate :neurodivergent_identifications_are_controlled
  validate :exclusive_neurodivergent_identifications_stand_alone

  private

  def neurodivergent_identifications_are_controlled
    invalid = Array(neurodivergent_identifications) - NEURODIVERGENT_IDENTIFICATIONS
    return if invalid.empty?

    errors.add(:neurodivergent_identifications, :inclusion)
  end

  def exclusive_neurodivergent_identifications_stand_alone
    selected = Array(neurodivergent_identifications)
    return if selected.length <= 1
    return if (selected & MUTUALLY_EXCLUSIVE_IDENTIFICATIONS).empty?

    errors.add(:neurodivergent_identifications, :mutually_exclusive)
  end
end
