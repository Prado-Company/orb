#!/usr/bin/env bash

test_contract_event_envelope() {
  local fixtures="$ROOT_DIR/packages/contracts/fixtures"
  assert_contract_fixture "$fixtures" "*event*" "Fixture de evento deve existir"
  assert_any_file_contains "$fixtures" '"event"|"event_type"' "Evento deve nomear o fato"
  assert_any_file_contains "$fixtures" '"version"' "Evento deve ter version"
  assert_any_file_contains "$fixtures" '"occurred_at"' "Evento deve ter occurred_at"
  assert_any_file_contains "$fixtures" '"source"' "Evento deve ter source"
  assert_any_file_contains "$fixtures" '"actor"' "Evento deve ter actor"
  assert_any_file_contains "$fixtures" '"correlation_id"' "Evento deve ter correlation_id"
  assert_any_file_contains "$fixtures" '"privacy_level"' "Evento deve ter privacy_level"
}

test_contract_error_envelope() {
  local fixtures="$ROOT_DIR/packages/contracts/fixtures"
  assert_contract_fixture "$fixtures" "*error*" "Fixture de erro deve existir"
  assert_any_file_contains "$fixtures" '"code"' "Erro deve ter code"
  assert_any_file_contains "$fixtures" '"message"' "Erro deve ter message"
  assert_any_file_contains "$fixtures" '"details"' "Erro deve ter details"
  assert_any_file_contains "$fixtures" '"correlation_id"' "Erro deve ter correlation_id"
  assert_no_file_contains "$fixtures" 'api_key|token|prompt_completo|senha|password' "Fixtures nao devem expor segredo/prompt completo"
}

test_contract_entities_coverage() {
  local fixtures="$ROOT_DIR/packages/contracts/fixtures"
  local required=(
    "*usuario*"
    "*perfil*energetico*"
    "*tarefa*"
    "*evento*"
    "*check*in*"
    "*energia*"
    "*sugestao*"
    "*intervencao*"
    "*entitlement*"
    "*audit*"
    "*export*"
    "*deletion*"
  )
  local pattern
  for pattern in "${required[@]}"; do
    assert_contract_fixture "$fixtures" "$pattern" "Fixture de entidade obrigatoria deve existir"
  done
}

test_contract_privacy_levels_sources() {
  local fixtures="$ROOT_DIR/packages/contracts/fixtures"
  assert_any_file_contains "$fixtures" 'publico|interno|sensivel|agregado|financeiro' "Niveis de privacidade devem estar presentes"
  assert_any_file_contains "$fixtures" 'web|android|ios|admin|job|integration' "Sources validos devem estar presentes"
  assert_no_file_contains "$fixtures" 'produtivo|baixa energia individual para gestor|ranking_publico' "Contratos nao podem introduzir estados/visibilidade proibidos"
}

test_contract_openapi_error_and_idempotency() {
  local openapi="$ROOT_DIR/packages/contracts/openapi.yaml"
  assert_file_contains "$openapi" 'Error|error|erro' "OpenAPI deve declarar schema de erro"
  assert_file_contains "$openapi" 'Idempotency-Key|idempotency_key|idempotency-key' "Mutacoes criticas devem aceitar idempotency key"
  assert_file_contains "$openapi" '/api/v1' "OpenAPI deve ser versionado em /api/v1"
  assert_file_contains "$openapi" 'cookie|session|bearer|token' "OpenAPI deve declarar autenticacao"
}

test_contract_no_forbidden_scope_v1() {
  assert_no_file_contains "$ROOT_DIR/apps/web" 'offline.*mode|modo offline|PWA|desktop app|SSO|webhook publico|public webhook' "v1 web nao deve implementar escopo pos-v1 por acidente"
  assert_no_file_contains "$ROOT_DIR/api" 'LLM.*decide|llm_decides|AI decided|IA decidiu|decide_with_llm' "LLM nao pode decidir regra critica"
  assert_no_file_contains "$ROOT_DIR/api" 'energia_individual.*gestor|manager.*individual.*energy|check_in.*leader' "Teams nao pode expor energia/check-in individual"
}

test_contract_security_lgpd_redaction() {
  assert_any_file_contains "$ROOT_DIR/api" 'filter_parameters|redact|LogSanitizer' "Redaction deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'audit_log|AuditLog' "Audit log deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'data_export_request|DataExport|RequestExport' "Exportacao LGPD deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'data_deletion_request|HardDelete|RequestDeletion' "Exclusao LGPD deve existir"
  assert_no_file_contains "$ROOT_DIR/api" 'puts.*password|logger.*password|logger.*token|logger.*prompt' "Logs nao podem registrar segredo ou prompt bruto"
}

run_case "CONTRACT-01" "contracts" "fixture de evento segue envelope unico" ".docs/contratos-produto.md" test_contract_event_envelope
run_case "CONTRACT-02" "contracts" "fixture de erro usa envelope seguro" ".docs/stack.md" test_contract_error_envelope
run_case "CONTRACT-03" "contracts" "fixtures cobrem entidades centrais ate v1" ".docs/contratos-produto.md" test_contract_entities_coverage
run_case "CONTRACT-04" "contracts" "privacidade e source sao padronizados" ".docs/contratos-produto.md" test_contract_privacy_levels_sources
run_case "CONTRACT-05" "contracts" "OpenAPI versiona /api/v1, erros e idempotencia" ".docs/stack.md" test_contract_openapi_error_and_idempotency
run_case "CONTRACT-06" "contracts" "escopos proibidos nao entram por acidente na v1" ".docs/escopo-v1.md" test_contract_no_forbidden_scope_v1
run_case "CONTRACT-07" "contracts" "LGPD, auditoria e redaction sao transversais" ".docs/privacidade-lgpd.md" test_contract_security_lgpd_redaction
