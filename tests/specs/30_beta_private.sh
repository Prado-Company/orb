#!/usr/bin/env bash

test_beta_entitlements_free_pro() {
  assert_any_file_contains "$ROOT_DIR/api" 'Entitlement|plano_entitlement|PlanEntitlement' "Entitlement central deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'free.*2|2.*check' "Entitlement Free deve limitar 2 check-ins"
  assert_any_file_contains "$ROOT_DIR/api" 'pro.*5|5.*check' "Entitlement Pro deve liberar 5 check-ins"
  assert_any_file_contains "$ROOT_DIR/api" 'micro_passo.*30|30.*micro' "Pro deve ter 30 micro-passos/mes"
  assert_any_file_contains "$ROOT_DIR/api" 'ui|api|job|admin|ia|ai' "Contrato deve ser consultavel por UI/API/jobs/IA/admin"
}

test_beta_billing_asaas_idempotent() {
  assert_any_file_contains "$ROOT_DIR/api" 'Asaas|asaas' "Adapter Asaas server-side deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'webhook|Billing::Sync|BillingSync' "Billing sync/webhook deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'idempotency|idempotente|processed_event' "Webhook duplicado deve ser idempotente"
  assert_any_file_contains "$ROOT_DIR/api" 'trial|cancelamento|inadimplencia|overdue' "Trial, cancelamento e inadimplencia devem alterar acesso"
  assert_no_file_contains "$ROOT_DIR/apps/web" 'ASAAS|asaas_api_key|api_key' "Segredo Asaas nao pode aparecer no frontend"
}

test_beta_billing_audit() {
  assert_any_file_contains "$ROOT_DIR/api" 'assinatura_alterada|subscription_changed' "Mudanca de assinatura deve gerar evento"
  assert_any_file_contains "$ROOT_DIR/api" 'audit_log|AuditLog' "Billing deve gerar audit log"
  assert_any_file_contains "$ROOT_DIR/api" 'payload_min|metadata_minima|redact|filter' "Audit log financeiro deve minimizar payload sensivel"
}

test_beta_full_onboarding_notifications() {
  assert_any_file_contains "$ROOT_DIR/apps/web" '1 de 12|12' "Onboarding completo deve ter 12 telas"
  assert_any_file_contains "$ROOT_DIR/api" 'revisao_solicitada|profile_version|perfil.*versao' "Revisao do onboarding deve preservar historico"
  assert_any_file_contains "$ROOT_DIR/api" 'identificacoes_neurodivergentes|neurodiverg' "Neurodivergencia opcional deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'minima|equilibrado|presente' "Preferencias de notificacao devem existir"
  assert_any_file_contains "$ROOT_DIR/api" 'ScheduledCheckInJob|check.*job' "Job de check-in agendado deve existir"
}

test_beta_neurodivergence_policy() {
  assert_any_file_contains "$ROOT_DIR/api" 'NeurodivergenceUsePolicy|Neurodivergencia|identificacoes_neurodivergentes' "Policy de uso de neurodivergencia deve existir"
  assert_no_file_contains "$ROOT_DIR/api" 'neurodiverg.*preco|preco.*neurodiverg|neurodiverg.*ranking|ranking.*neurodiverg' "Neurodivergencia nao pode afetar preco/ranking"
  assert_no_file_contains "$ROOT_DIR/apps/web" 'diagnostico confirmado|diagnóstico confirmado|tratamento garantido|vamos diagnosticar|vamos tratar|substitui apoio profissional' "UI nao deve prometer diagnostico/tratamento"
}

test_beta_ai_router_cache_quota_fallback() {
  assert_any_file_contains "$ROOT_DIR/api" 'TextOutputRouter|template.*cache.*LLM|llm.*fallback' "Router de texto deve seguir ordem template/cache/LLM/fallback"
  assert_any_file_contains "$ROOT_DIR/api" 'cache_key|task:.*micro_passo|micro_passo.*v1' "Cache exato por item deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'quota|limite|usage' "Quota de IA deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'fallback' "Fallback textual deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'cache_hit|privacy_block|quota_block|custo_estimado|tokens' "Log de custo IA deve registrar status e custo"
}

test_beta_micro_step_and_weekly_insight() {
  assert_any_file_contains "$ROOT_DIR/api" 'micro_passo|micro_step' "Micro-passo Pro deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'one.*per.*task|um.*por.*tarefa|unique.*task' "Micro-passo deve ser unico por tarefa"
  assert_any_file_contains "$ROOT_DIR/api" 'WeeklyInsightJob|weekly.*insight|insight.*semanal' "Insight semanal Pro deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'llm_decides.*false|LLM.*narra|pre.?processado' "LLM deve apenas narrar dados pre-processados"
}

test_beta_lgpd_export_delete() {
  assert_any_file_contains "$ROOT_DIR/api" 'RequestExport|DataExport|data_export_request' "Pedido de exportacao deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'csv|json' "Exportacao deve gerar CSV/JSON"
  assert_any_file_contains "$ROOT_DIR/api" 'RequestDeletion|DataDeletion|data_deletion_request' "Pedido de exclusao deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'soft_delete.*imediat|soft_delete_at|soft_delete_aplicado' "Soft delete deve ser imediato"
  assert_any_file_contains "$ROOT_DIR/api" '30.*days|30.*dias|hard_delete_scheduled_at' "Hard delete deve ser agendado em ate 30 dias"
}

test_beta_admin_observability() {
  assert_any_file_contains "$ROOT_DIR/api" 'Admin|admin' "Admin minimo deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'MFA|2FA|two_factor|justificativa' "Acesso admin sensivel exige MFA/justificativa"
  assert_any_file_contains "$ROOT_DIR/api" 'FeatureFlag|feature_flag|kill.?switch' "Feature flags devem existir"
  assert_any_file_contains "$ROOT_DIR/api" 'Sentry|OpenTelemetry|otel|structured.*log' "Observabilidade core deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'p95|p99|latenc|job|billing|custo' "Observabilidade deve medir latencia/jobs/billing/IA"
}

run_case "BETA-01" "beta" "entitlements Free/Pro sao regra central" ".docs/tasks-roadmap-v1.md" test_beta_entitlements_free_pro
run_case "BETA-02" "beta" "billing Asaas e webhook sao server-side e idempotentes" ".docs/runbooks-v1.md" test_beta_billing_asaas_idempotent
run_case "BETA-03" "beta" "billing gera eventos e auditoria minimizada" ".docs/privacidade-lgpd.md" test_beta_billing_audit
run_case "BETA-04" "beta" "onboarding completo, revisao e notificacoes existem" ".docs/onboarding.md" test_beta_full_onboarding_notifications
run_case "BETA-05" "beta" "neurodivergencia opcional nao discrimina nem promete medicina" ".docs/privacidade-lgpd.md" test_beta_neurodivergence_policy
run_case "BETA-06" "beta" "IA segue template, cache, quota, LLM e fallback" ".docs/ml-llm.md" test_beta_ai_router_cache_quota_fallback
run_case "BETA-07" "beta" "micro-passo e insight semanal preservam decisao deterministica" ".docs/ml-llm.md" test_beta_micro_step_and_weekly_insight
run_case "BETA-08" "beta" "LGPD exporta CSV/JSON e exclui com soft/hard delete" ".docs/privacidade-lgpd.md" test_beta_lgpd_export_delete
run_case "BETA-09" "beta" "admin, feature flags e observabilidade sustentam operacao" ".docs/tasks-roadmap-v1.md" test_beta_admin_observability
