class CreateFoundationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :pronouns
      t.string :password_digest, null: false
      t.string :timezone, null: false, default: "UTC"
      t.string :locale, null: false, default: "pt-BR"
      t.string :plan, null: false, default: "free"
      t.string :account_status, null: false, default: "active"
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :account_status

    create_table :api_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :source, null: false, default: "web"
      t.string :correlation_id, null: false
      t.string :ip_hash
      t.string :user_agent_hash
      t.timestamps
    end
    add_index :api_sessions, :token_digest, unique: true
    add_index :api_sessions, %i[user_id revoked_at expires_at]

    create_table :organizations do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :plan, null: false, default: "teams"
      t.string :status, null: false, default: "active"
      t.jsonb :privacy_settings, null: false, default: { group_minimum: 3, expose_individual_sensitive_data: false }
      t.timestamps
    end

    create_table :organization_memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :organization_memberships, %i[organization_id user_id], unique: true, name: "idx_org_memberships_org_user"

    create_table :permissions do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :role, null: false
      t.string :scope, null: false
      t.string :resource, null: false
      t.jsonb :allowed_actions, null: false, default: []
      t.datetime :valid_from, null: false
      t.datetime :valid_until
      t.references :granted_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, foreign_key: true
      t.string :title, null: false
      t.string :category
      t.date :due_on
      t.integer :estimated_minutes
      t.string :weight
      t.string :status, null: false, default: "nao_iniciado"
      t.string :origin, null: false, default: "user"
      t.bigint :responsible_id
      t.text :context
      t.string :micro_step_id
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :tasks, %i[user_id status]
    add_index :tasks, :deleted_at

    create_table :events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, foreign_key: true
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, null: false
      t.string :category
      t.string :weight
      t.string :status, null: false, default: "confirmado"
      t.string :origin, null: false, default: "user"
      t.string :external_ref
      t.jsonb :recurrence, null: false, default: {}
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :events, %i[user_id starts_at]
    add_index :events, %i[user_id external_ref], unique: true, where: "external_ref IS NOT NULL"
    add_index :events, :deleted_at

    create_table :energetic_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :archetype, null: false
      t.string :main_goal, null: false
      t.jsonb :peak_windows, null: false, default: []
      t.jsonb :low_energy_windows, null: false, default: []
      t.jsonb :triggers, null: false, default: []
      t.string :preferred_tone, null: false, default: "acolhedor"
      t.string :sensitivity, null: false, default: "media"
      t.string :notification_intensity, null: false, default: "equilibrado"
      t.string :first_check_in_time, null: false, default: "08:00"
      t.string :last_check_in_time, null: false, default: "18:00"
      t.jsonb :meal_times, null: false, default: []
      t.jsonb :protected_breaks, null: false, default: []
      t.string :confidence, null: false, default: "baixa"
      t.string :source, null: false, default: "web"
      t.timestamps
    end

    create_table :check_ins do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :question_id, null: false
      t.string :scheduled_time, null: false
      t.datetime :answered_at
      t.string :timezone, null: false
      t.integer :postponements, null: false, default: 0
      t.string :origin, null: false, default: "programado"
      t.string :response
      t.string :source, null: false, default: "web"
      t.timestamps
    end
    add_index :check_ins, %i[user_id scheduled_time]

    create_table :energies do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :value, null: false
      t.string :qualitative_state, null: false
      t.string :calibration_source, null: false
      t.string :confidence, null: false
      t.datetime :measured_at, null: false
      t.jsonb :factors, null: false, default: []
      t.string :source, null: false, default: "web"
      t.timestamps
    end
    add_index :energies, %i[user_id measured_at]

    create_table :suggestions do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :summarized_input, null: false, default: {}
      t.string :suggested_item_type
      t.bigint :suggested_item_id
      t.text :reason
      t.jsonb :available_actions, null: false, default: []
      t.string :action_taken
      t.string :source, null: false, default: "web"
      t.string :privacy_level, null: false, default: "sensivel"
      t.timestamps
    end
    add_index :suggestions, %i[user_id created_at]

    create_table :interventions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :intervention_type, null: false
      t.string :trigger
      t.integer :estimated_minutes, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :estimated_effect
      t.string :feedback
      t.string :source, null: false, default: "web"
      t.timestamps
    end
    add_index :interventions, %i[user_id started_at]

    create_table :plan_entitlements do |t|
      t.references :user, foreign_key: true
      t.references :organization, foreign_key: true
      t.string :plan, null: false
      t.string :feature, null: false
      t.integer :limit
      t.string :period, null: false, default: "mensal"
      t.integer :current_usage, null: false, default: 0
      t.string :origin, null: false, default: "sistema"
      t.date :valid_from, null: false
      t.date :valid_until
      t.string :subscription_state, null: false, default: "ativa"
      t.timestamps
    end
    add_index :plan_entitlements, %i[user_id feature]

    create_table :audit_logs do |t|
      t.string :actor_type, null: false
      t.bigint :actor_id
      t.string :action, null: false
      t.string :resource_type
      t.bigint :resource_id
      t.string :justification
      t.string :privacy_level, null: false
      t.string :correlation_id, null: false
      t.jsonb :metadata_minima, null: false, default: {}
      t.timestamps
    end
    add_index :audit_logs, %i[actor_type actor_id]
    add_index :audit_logs, %i[resource_type resource_id]

    create_table :domain_events do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.string :actor_type, null: false
      t.string :actor_id, null: false
      t.string :resource_type, null: false
      t.string :resource_id, null: false
      t.string :source, null: false
      t.string :correlation_id, null: false
      t.string :privacy_level, null: false
      t.jsonb :metadata_minima, null: false, default: {}
      t.timestamps
    end
    add_index :domain_events, :event_id, unique: true
    add_index :domain_events, %i[event_type occurred_at]
    add_index :domain_events, :correlation_id

    create_table :data_export_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "processando"
      t.jsonb :formats, null: false, default: %w[json csv]
      t.boolean :visible_to_user, null: false, default: true
      t.datetime :requested_at, null: false
      t.datetime :completed_at
      t.datetime :expires_at
      t.string :source, null: false, default: "web"
      t.timestamps
    end

    create_table :data_deletion_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "soft_delete_aplicado"
      t.datetime :requested_at, null: false
      t.datetime :soft_deleted_at, null: false
      t.datetime :hard_delete_scheduled_at, null: false
      t.datetime :completed_at
      t.jsonb :legal_retentions, null: false, default: ["billing"]
      t.string :source, null: false, default: "web"
      t.timestamps
    end

    create_table :ai_usage_logs do |t|
      t.references :user, foreign_key: true
      t.string :usage_type, null: false
      t.string :provider
      t.string :model_name
      t.string :status, null: false
      t.integer :cost_cents, null: false, default: 0
      t.boolean :cache_hit, null: false, default: false
      t.boolean :fallback_used, null: false, default: false
      t.string :prompt_fingerprint
      t.string :source, null: false, default: "job"
      t.string :correlation_id, null: false
      t.jsonb :metadata_minima, null: false, default: {}
      t.timestamps
    end
    add_index :ai_usage_logs, %i[user_id usage_type created_at]
  end
end
