#!/usr/bin/env bash

test_v1_calendar_read_only_sync() {
  assert_any_file_contains "$ROOT_DIR/api" 'GoogleCalendar|Calendar|calendario' "Integracao de calendario externo deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'consent|consentimento|revogacao|revogar' "Calendario deve exigir consentimento e permitir revogacao"
  assert_any_file_contains "$ROOT_DIR/api" 'read_only|somente.*leitura|leitura' "Calendario v1 deve ser read-only"
  assert_any_file_contains "$ROOT_DIR/api" 'external_ref|sync|last_sync|retry' "Sync deve registrar external_ref, estado e retry"
  assert_any_file_contains "$ROOT_DIR/api" 'idempot|duplicate|duplicidade' "Sync repetido deve ser idempotente"
}

test_v1_regulation_content() {
  assert_any_file_contains "$ROOT_DIR/api" 'audio_conteudo|RegulationContent|Conteudo' "Conteudo de regulacao deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'audio|respiracao|exercicio|template|tarefa_modelo' "Conteudo deve cobrir audio, respiracao, exercicio, template e tarefa-modelo"
  assert_any_file_contains "$ROOT_DIR/api" 'plano|entitlement|free|pro' "Conteudo deve respeitar plano"
  assert_any_file_contains "$ROOT_DIR/api" 'fallback.*text|texto.*fallback|fallback_textual' "Audio/regulacao deve ter fallback textual"
  assert_any_file_contains "$ROOT_DIR/api" 'admin.*conteudo|ContentAdmin|Admin::.*Content' "Admin de conteudo deve existir"
}

test_v1_web_core_routes() {
  assert_any_file_contains "$ROOT_DIR/apps/web" '/hoje|Hoje|today' "Home /hoje deve existir"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'tasks|tarefas|events|eventos' "Web deve completar tarefas/eventos"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'historico|history' "Web deve completar historico por plano"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'perfil|settings|configuracoes' "Web deve completar perfil/configuracoes"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'billing|plano|assinatura|cancelamento' "Web deve completar billing"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'exportacao|exclusao|LGPD|privacidade' "Web deve completar fluxos LGPD"
}

test_v1_responsive_accessible_microcopy() {
  assert_any_file_contains "$ROOT_DIR/apps/web" 'viewport|mobile|desktop|responsive|md:' "Web deve ter responsividade mobile/desktop"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'aria-|role=|label|focus-visible|keyboard' "Web deve ter acessibilidade basica"
  assert_no_file_contains "$ROOT_DIR/apps/web" 'voce falhou|você falhou|culpa|preguica|preguiça' "Microcopy nao pode culpar o usuario"
  assert_no_file_contains "$ROOT_DIR/apps/web" 'offline|PWA|instalar app' "v1 web nao deve prometer offline/PWA"
}

test_v1_rate_limits_backups_storage() {
  assert_any_file_contains "$ROOT_DIR/api" 'rate.?limit|Rack::Attack|throttle' "Rate limits devem proteger auth/check-ins/micro-passo/export/billing"
  assert_any_file_contains "$ROOT_DIR/api" 'S3|s3|storage|bucket|ActiveStorage' "Storage S3-compatible deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'backup|PITR|point.?in.?time|restore' "Backups/PITR ou politica de restore deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'redact|filter_parameters|LogSanitizer' "Redaction final deve cobrir logs Rails/jobs/observabilidade"
}

test_v1_degradation() {
  assert_any_file_contains "$ROOT_DIR/api" 'LLM.*fallback|fallback.*LLM|llm.*timeout' "Falha de LLM deve cair em fallback"
  assert_any_file_contains "$ROOT_DIR/api" 'calendar.*failure|sync.*error|external.*failure|integracao.*falha' "Falha de calendario externo nao deve quebrar dados internos"
  assert_any_file_contains "$ROOT_DIR/api" 'email.*retry|notification.*retry|notificacao.*retry' "Falha de email/notificacao deve registrar retry"
  assert_any_file_contains "$ROOT_DIR/api" 'billing.*instavel|billing.*sync|overdue.*confirm' "Billing instavel nao pode apagar dados ou bloquear indevidamente"
}

test_v1_release_regression() {
  assert_dir_exists "$ROOT_DIR/api/spec" "Regressao API deve existir em api/spec"
  assert_any_file_contains "$ROOT_DIR/api/spec" 'contract|request|job|domain|lgpd|billing' "Regressao API deve cobrir contratos, dominio, requests, jobs, LGPD e billing"
  assert_dir_exists "$ROOT_DIR/apps/web/e2e" "Regressao E2E deve existir"
  assert_any_file_contains "$ROOT_DIR/apps/web/e2e" 'Free|Pro|billing|LGPD|calendar|regulacao|regulação' "E2E deve cobrir Free/Pro, billing, LGPD, calendario e regulacao"
  assert_dir_exists "$ROOT_DIR/tests/load" "Smoke de carga deve existir"
  assert_any_file_contains "$ROOT_DIR/tests" 'go/no-go|go no go|go_nogo|rollback' "Checklist de release/rollback deve existir"
}

test_v1_runbooks_operational_evidence() {
  assert_file_contains "$ROOT_DIR/.docs/runbooks-v1.md" 'Billing' "Runbook de billing deve existir"
  assert_file_contains "$ROOT_DIR/.docs/runbooks-v1.md" 'IA' "Runbook de IA deve existir"
  assert_file_contains "$ROOT_DIR/.docs/runbooks-v1.md" 'LGPD' "Runbook LGPD deve existir"
  assert_file_contains "$ROOT_DIR/.docs/runbooks-v1.md" 'Jobs' "Runbook de jobs deve existir"
  assert_file_contains "$ROOT_DIR/.docs/runbooks-v1.md" 'Incidentes' "Runbook de incidentes deve existir"
  assert_any_file_contains "$ROOT_DIR/tests" 'degradacao|degradation|LLM.*fora|billing.*instavel' "Runbooks devem ter testes de degradacao associados"
}

run_case "V1-01" "v1" "calendario externo e read-only, consentido e idempotente" ".docs/tasks-roadmap-v1.md" test_v1_calendar_read_only_sync
run_case "V1-02" "v1" "conteudo de regulacao possui admin, plano e fallback textual" ".docs/escopo-v1.md" test_v1_regulation_content
run_case "V1-03" "v1" "web completa /hoje, tarefas, historico, perfil, billing e LGPD" ".docs/tasks-roadmap-v1.md" test_v1_web_core_routes
run_case "V1-04" "v1" "web e responsiva, acessivel e sem microcopy punitiva" ".docs/onboarding.md" test_v1_responsive_accessible_microcopy
run_case "V1-05" "v1" "rate limits, storage, backups e redaction estao configurados" ".docs/requisitos-stack.md" test_v1_rate_limits_backups_storage
run_case "V1-06" "v1" "degradacao protege core quando terceiros falham" ".docs/runbooks-v1.md" test_v1_degradation
run_case "V1-07" "v1" "regressao API/E2E, carga e go-no-go existem" ".docs/tasks-roadmap-v1.md" test_v1_release_regression
run_case "V1-08" "v1" "runbooks v1 possuem evidencia de teste operacional" ".docs/runbooks-v1.md" test_v1_runbooks_operational_evidence
