class AddOnboardingProgressToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarding_state, :string, null: false, default: "nao_iniciado"
    add_column :users, :onboarding_progress, :jsonb, null: false, default: {}
    add_column :users, :onboarding_started_at, :datetime
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_skipped_at, :datetime
    add_column :users, :onboarding_profile_version, :integer, null: false, default: 0

    add_index :users, :onboarding_state

    add_column :energetic_profiles, :neurodivergent_identifications, :jsonb, null: false, default: []
  end
end
