# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_14_001000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_usage_logs", force: :cascade do |t|
    t.boolean "cache_hit", default: false, null: false
    t.string "correlation_id", null: false
    t.integer "cost_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "fallback_used", default: false, null: false
    t.jsonb "metadata_minima", default: {}, null: false
    t.string "model_name"
    t.string "prompt_fingerprint"
    t.string "provider"
    t.string "source", default: "job", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.string "usage_type", null: false
    t.bigint "user_id"
    t.index ["user_id", "usage_type", "created_at"], name: "index_ai_usage_logs_on_user_id_and_usage_type_and_created_at"
    t.index ["user_id"], name: "index_ai_usage_logs_on_user_id"
  end

  create_table "api_sessions", force: :cascade do |t|
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_hash"
    t.datetime "revoked_at"
    t.string "source", default: "web", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent_hash"
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_sessions_on_token_digest", unique: true
    t.index ["user_id", "revoked_at", "expires_at"], name: "index_api_sessions_on_user_id_and_revoked_at_and_expires_at"
    t.index ["user_id"], name: "index_api_sessions_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.string "actor_type", null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "justification"
    t.jsonb "metadata_minima", default: {}, null: false
    t.string "privacy_level", null: false
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_audit_logs_on_actor_type_and_actor_id"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
  end

  create_table "check_ins", force: :cascade do |t|
    t.datetime "answered_at"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "origin", default: "programado", null: false
    t.integer "postponements", default: 0, null: false
    t.string "question_id", null: false
    t.string "response"
    t.string "scheduled_time", null: false
    t.string "source", default: "web", null: false
    t.string "timezone", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "scheduled_time"], name: "index_check_ins_on_user_id_and_scheduled_time"
    t.index ["user_id"], name: "index_check_ins_on_user_id"
  end

  create_table "data_deletion_requests", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "hard_delete_scheduled_at", null: false
    t.jsonb "legal_retentions", default: ["billing"], null: false
    t.datetime "requested_at", null: false
    t.datetime "soft_deleted_at", null: false
    t.string "source", default: "web", null: false
    t.string "status", default: "soft_delete_aplicado", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_data_deletion_requests_on_user_id"
  end

  create_table "data_export_requests", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.jsonb "formats", default: ["json", "csv"], null: false
    t.datetime "requested_at", null: false
    t.string "source", default: "web", null: false
    t.string "status", default: "processando", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.boolean "visible_to_user", default: true, null: false
    t.index ["user_id"], name: "index_data_export_requests_on_user_id"
  end

  create_table "domain_events", force: :cascade do |t|
    t.string "actor_id", null: false
    t.string "actor_type", null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.jsonb "metadata_minima", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.string "privacy_level", null: false
    t.string "resource_id", null: false
    t.string "resource_type", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["correlation_id"], name: "index_domain_events_on_correlation_id"
    t.index ["event_id"], name: "index_domain_events_on_event_id", unique: true
    t.index ["event_type", "occurred_at"], name: "index_domain_events_on_event_type_and_occurred_at"
  end

  create_table "energetic_profiles", force: :cascade do |t|
    t.string "archetype", null: false
    t.string "confidence", default: "baixa", null: false
    t.datetime "created_at", null: false
    t.string "first_check_in_time", default: "08:00", null: false
    t.string "last_check_in_time", default: "18:00", null: false
    t.jsonb "low_energy_windows", default: [], null: false
    t.string "main_goal", null: false
    t.jsonb "meal_times", default: [], null: false
    t.jsonb "neurodivergent_identifications", default: [], null: false
    t.string "notification_intensity", default: "equilibrado", null: false
    t.jsonb "peak_windows", default: [], null: false
    t.string "preferred_tone", default: "acolhedor", null: false
    t.jsonb "protected_breaks", default: [], null: false
    t.string "sensitivity", default: "media", null: false
    t.string "source", default: "web", null: false
    t.jsonb "triggers", default: [], null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_energetic_profiles_on_user_id"
  end

  create_table "energies", force: :cascade do |t|
    t.string "calibration_source", null: false
    t.string "confidence", null: false
    t.datetime "created_at", null: false
    t.jsonb "factors", default: [], null: false
    t.datetime "measured_at", null: false
    t.string "qualitative_state", null: false
    t.string "source", default: "web", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "value", null: false
    t.index ["user_id", "measured_at"], name: "index_energies_on_user_id_and_measured_at"
    t.index ["user_id"], name: "index_energies_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "ends_at", null: false
    t.string "external_ref"
    t.bigint "organization_id"
    t.string "origin", default: "user", null: false
    t.jsonb "recurrence", default: {}, null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "confirmado", null: false
    t.string "timezone", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "weight"
    t.index ["deleted_at"], name: "index_events_on_deleted_at"
    t.index ["organization_id"], name: "index_events_on_organization_id"
    t.index ["user_id", "external_ref"], name: "index_events_on_user_id_and_external_ref", unique: true, where: "(external_ref IS NOT NULL)"
    t.index ["user_id", "starts_at"], name: "index_events_on_user_id_and_starts_at"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "interventions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "estimated_effect"
    t.integer "estimated_minutes", null: false
    t.string "feedback"
    t.string "intervention_type", null: false
    t.string "source", default: "web", null: false
    t.datetime "started_at", null: false
    t.string "trigger"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "started_at"], name: "index_interventions_on_user_id_and_started_at"
    t.index ["user_id"], name: "index_interventions_on_user_id"
  end

  create_table "organization_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id", "user_id"], name: "idx_org_memberships_org_user", unique: true
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.string "plan", default: "teams", null: false
    t.jsonb "privacy_settings", default: {"group_minimum" => 3, "expose_individual_sensitive_data" => false}, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_organizations_on_owner_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.jsonb "allowed_actions", default: [], null: false
    t.datetime "created_at", null: false
    t.bigint "granted_by_id"
    t.string "resource", null: false
    t.string "role", null: false
    t.string "scope", null: false
    t.datetime "updated_at", null: false
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.index ["actor_id"], name: "index_permissions_on_actor_id"
    t.index ["granted_by_id"], name: "index_permissions_on_granted_by_id"
  end

  create_table "plan_entitlements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_usage", default: 0, null: false
    t.string "feature", null: false
    t.integer "limit"
    t.bigint "organization_id"
    t.string "origin", default: "sistema", null: false
    t.string "period", default: "mensal", null: false
    t.string "plan", null: false
    t.string "subscription_state", default: "ativa", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.date "valid_from", null: false
    t.date "valid_until"
    t.index ["organization_id"], name: "index_plan_entitlements_on_organization_id"
    t.index ["user_id", "feature"], name: "index_plan_entitlements_on_user_id_and_feature"
    t.index ["user_id"], name: "index_plan_entitlements_on_user_id"
  end

  create_table "suggestions", force: :cascade do |t|
    t.string "action_taken"
    t.jsonb "available_actions", default: [], null: false
    t.datetime "created_at", null: false
    t.string "privacy_level", default: "sensivel", null: false
    t.text "reason"
    t.string "source", default: "web", null: false
    t.bigint "suggested_item_id"
    t.string "suggested_item_type"
    t.jsonb "summarized_input", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_suggestions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_suggestions_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "category"
    t.text "context"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.date "due_on"
    t.integer "estimated_minutes"
    t.string "micro_step_id"
    t.bigint "organization_id"
    t.string "origin", default: "user", null: false
    t.bigint "responsible_id"
    t.string "status", default: "nao_iniciado", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "weight"
    t.index ["deleted_at"], name: "index_tasks_on_deleted_at"
    t.index ["organization_id"], name: "index_tasks_on_organization_id"
    t.index ["user_id", "status"], name: "index_tasks_on_user_id_and_status"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "account_status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", null: false
    t.string "locale", default: "pt-BR", null: false
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.integer "onboarding_profile_version", default: 0, null: false
    t.jsonb "onboarding_progress", default: {}, null: false
    t.datetime "onboarding_skipped_at"
    t.datetime "onboarding_started_at"
    t.string "onboarding_state", default: "nao_iniciado", null: false
    t.string "password_digest", null: false
    t.string "plan", default: "free", null: false
    t.string "pronouns"
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["account_status"], name: "index_users_on_account_status"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["onboarding_state"], name: "index_users_on_onboarding_state"
  end

  add_foreign_key "ai_usage_logs", "users"
  add_foreign_key "api_sessions", "users"
  add_foreign_key "check_ins", "users"
  add_foreign_key "data_deletion_requests", "users"
  add_foreign_key "data_export_requests", "users"
  add_foreign_key "energetic_profiles", "users"
  add_foreign_key "energies", "users"
  add_foreign_key "events", "organizations"
  add_foreign_key "events", "users"
  add_foreign_key "interventions", "users"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "organizations", "users", column: "owner_id"
  add_foreign_key "permissions", "users", column: "actor_id"
  add_foreign_key "permissions", "users", column: "granted_by_id"
  add_foreign_key "plan_entitlements", "organizations"
  add_foreign_key "plan_entitlements", "users"
  add_foreign_key "suggestions", "users"
  add_foreign_key "tasks", "organizations"
  add_foreign_key "tasks", "users"
end
