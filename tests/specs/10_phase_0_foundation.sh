#!/usr/bin/env bash

test_f0_repo_shape() {
  assert_dir_exists "$ROOT_DIR/api" "Rails API deve nascer em api/"
  assert_dir_exists "$ROOT_DIR/apps/web" "React/Vite deve nascer em apps/web/"
  assert_dir_exists "$ROOT_DIR/apps/ml-worker" "Worker Python ML deve nascer em apps/ml-worker/"
  assert_dir_exists "$ROOT_DIR/packages/contracts" "Contratos compartilhados devem nascer em packages/contracts/"
  assert_dir_exists "$ROOT_DIR/packages/design" "Tokens/componentes compartilhaveis devem nascer em packages/design/"
}

test_f0_rails_api_scaffold() {
  assert_file_exists "$ROOT_DIR/api/config.ru" "Rails API-only deve expor config.ru"
  assert_file_exists "$ROOT_DIR/api/Gemfile" "Rails API deve declarar Gemfile"
  assert_file_contains "$ROOT_DIR/api/config/routes.rb" 'api[\/_]?v1|namespace[[:space:]]+:api|/api/v1' "Rotas devem conter namespace REST /api/v1"
  assert_any_file_contains "$ROOT_DIR/api" 'Rails\.application|ActionController::API' "Backend deve ser Rails API"
}

test_f0_web_scaffold() {
  local pkg="$ROOT_DIR/apps/web/package.json"
  assert_file_exists "$pkg" "Web Vite/React deve declarar package.json"
  assert_file_exists "$ROOT_DIR/apps/web/tsconfig.json" "Web deve usar TypeScript"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'vite|@vitejs/plugin-react' "Web deve usar Vite + React"
  assert_package_json_script "$pkg" "dev" "Web deve ter script dev"
  assert_package_json_script "$pkg" "build" "Web deve ter script build"
  assert_package_json_script "$pkg" "test:e2e" "Web deve ter script test:e2e"
}

test_f0_ml_worker_scaffold() {
  assert_file_exists "$ROOT_DIR/apps/ml-worker/pyproject.toml" "Worker ML deve declarar pyproject.toml"
  assert_any_file_contains "$ROOT_DIR/apps/ml-worker" 'FastAPI|pydantic|polars|pandas|scikit-learn|sklearn' "Worker ML deve usar FastAPI/Pydantic e libs estatisticas leves"
  assert_no_file_contains "$ROOT_DIR/apps/ml-worker" 'llm_decides|decide_next_action|decide_energy' "ML worker nao pode decidir energia ou proxima acao"
}

test_f0_postgres_and_migrations() {
  assert_file_contains "$ROOT_DIR/api/config/database.yml" 'postgres|postgresql' "Banco oficial deve ser PostgreSQL"
  assert_dir_exists "$ROOT_DIR/api/db/migrate" "Migrations Rails devem existir"
  assert_any_file_contains "$ROOT_DIR/api/db/migrate" 'create_table.*users|create_table.*usuarios' "Migration base deve criar usuarios"
  assert_any_file_contains "$ROOT_DIR/api/db/migrate" 'create_table.*tasks|create_table.*tarefas' "Migration base deve criar tarefas"
  assert_any_file_contains "$ROOT_DIR/api/db/migrate" 'create_table.*events|create_table.*eventos' "Migration base deve criar eventos"
}

test_f0_solid_queue_registry() {
  local queues='billing|lgpd|notifications|insights|ml_batch|exports|maintenance'
  assert_any_file_contains "$ROOT_DIR/api" 'SolidQueue|solid_queue' "Jobs iniciais devem usar Solid Queue"
  assert_any_file_contains "$ROOT_DIR/api" "$queues" "Filas nomeadas obrigatorias devem estar configuradas"
  assert_any_file_contains "$ROOT_DIR/api" 'idempot|retry|correlation_id' "Jobs criticos devem declarar idempotencia, retry e correlation_id"
}

test_f0_valkey_cache_policy() {
  assert_any_file_contains "$ROOT_DIR/api" 'Valkey|Redis|redis' "Cache inicial deve usar adapter Valkey/Redis"
  assert_any_file_contains "$ROOT_DIR/api" 'ttl|expires_in|expire' "Toda chave de cache deve ter TTL obrigatorio"
  assert_any_file_contains "$ROOT_DIR/api" 'namespace|cache_key' "Cache deve usar namespaces/chaves controladas"
  assert_any_file_contains "$ROOT_DIR/api" 'fallback.*(redis|valkey)|redis.*fallback|valkey.*fallback' "Dev/test deve ter fallback sem Redis/Valkey"
}

test_f0_shared_contract_fixtures() {
  local fixtures="$ROOT_DIR/packages/contracts/fixtures"
  assert_contract_fixture "$fixtures" "*event*" "Fixture de envelope de evento deve existir"
  assert_contract_fixture "$fixtures" "*error*" "Fixture de erro padrao deve existir"
  assert_contract_fixture "$fixtures" "*onboarding*" "Fixture de onboarding deve existir"
  assert_contract_fixture "$fixtures" "*next*action*" "Fixture de proxima acao deve existir"
}

test_f0_openapi_initial_contract() {
  local openapi="$ROOT_DIR/packages/contracts/openapi.yaml"
  assert_file_exists "$openapi" "OpenAPI versionado deve existir"
  assert_openapi_path "$openapi" '/api/v1/onboarding/complete|/onboarding/complete' "OpenAPI deve declarar onboarding complete"
  assert_openapi_path "$openapi" '/api/v1/onboarding/skip|/onboarding/skip' "OpenAPI deve declarar onboarding skip"
  assert_openapi_path "$openapi" '/api/v1/tasks|/tasks' "OpenAPI deve declarar tasks"
  assert_openapi_path "$openapi" '/api/v1/events|/events' "OpenAPI deve declarar events"
  assert_openapi_path "$openapi" '/api/v1/check_ins|/check_ins' "OpenAPI deve declarar check-ins"
  assert_openapi_path "$openapi" '/api/v1/suggestions/next_action|/suggestions/next_action' "OpenAPI deve declarar next_action"
  assert_file_contains "$openapi" 'correlation_id' "OpenAPI deve padronizar correlation_id"
}

test_f0_ci_minimum() {
  assert_dir_exists "$ROOT_DIR/.github/workflows" "CI deve existir em .github/workflows"
  assert_any_file_contains "$ROOT_DIR/.github/workflows" 'rspec|rails.*test|bundle exec' "CI deve rodar specs backend"
  assert_any_file_contains "$ROOT_DIR/.github/workflows" 'pnpm.*build|npm.*build|vite.*build' "CI deve rodar build frontend"
  assert_any_file_contains "$ROOT_DIR/.github/workflows" 'playwright|test:e2e' "CI deve rodar E2E"
  assert_any_file_contains "$ROOT_DIR/.github/workflows" 'openapi|contract|fixtures' "CI deve falhar em contrato quebrado"
}

test_f0_error_auth_isolation() {
  assert_any_file_contains "$ROOT_DIR/api" 'authentication_required|unauthenticated|authenticate' "Mutacoes sensiveis sem usuario devem falhar com authentication_required"
  assert_any_file_contains "$ROOT_DIR/api" 'Pundit|policy_scope|authorize' "Autorizacao deve usar Pundit/policies por recurso"
  assert_any_file_contains "$ROOT_DIR/api" 'correlation_id|X-Correlation-Id|X-Correlation-ID' "Requests/erros/eventos devem carregar correlation id"
  assert_any_file_contains "$ROOT_DIR/api" 'code.*message.*details.*correlation_id|correlation_id.*details.*message.*code' "Envelope de erro deve conter code, message, details e correlation_id"
}

test_f0_event_recorder_and_sanitizer() {
  assert_any_file_contains "$ROOT_DIR/api" 'EventRecorder|record_event|DomainEvent' "Event recorder deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'metadata_minima|payload_min|privacy_level' "Eventos devem minimizar payload sensivel"
  assert_any_file_contains "$ROOT_DIR/api" 'LogSanitizer|filter_parameters|redact' "Sanitizer de logs deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'token|prompt|check_in|neurodiverg|energia' "Sanitizer deve cobrir tokens, prompts, check-ins, neurodivergencia e energia"
}

run_case "F0-01" "fase-0" "estrutura oficial do monorepo existe" ".docs/stack.md" test_f0_repo_shape
run_case "F0-02" "fase-0" "Rails API-only expõe /api/v1" ".docs/tasks-roadmap-v1.md" test_f0_rails_api_scaffold
run_case "F0-03" "fase-0" "React/Vite TypeScript possui scripts dev/build/e2e" ".docs/stack.md" test_f0_web_scaffold
run_case "F0-04" "fase-0" "worker Python ML existe sem decidir regra critica" ".docs/ml-llm.md" test_f0_ml_worker_scaffold
run_case "F0-05" "fase-0" "Postgres e migrations base estao configurados" ".docs/tasks-roadmap-v1.md" test_f0_postgres_and_migrations
run_case "F0-06" "fase-0" "Solid Queue possui filas, retry, idempotencia e correlation id" ".docs/runbooks-v1.md" test_f0_solid_queue_registry
run_case "F0-07" "fase-0" "Valkey/Redis usa TTL, namespace e fallback dev/test" ".docs/stack.md" test_f0_valkey_cache_policy
run_case "F0-08" "fase-0" "fixtures compartilhadas existem em packages/contracts" ".docs/tasks-roadmap-v1.md" test_f0_shared_contract_fixtures
run_case "F0-09" "fase-0" "OpenAPI inicial cobre endpoints centrais" ".docs/stack.md" test_f0_openapi_initial_contract
run_case "F0-10" "fase-0" "CI minimo cobre backend, frontend, E2E e contratos" ".docs/tasks-roadmap-v1.md" test_f0_ci_minimum
run_case "F0-11" "fase-0" "auth, isolamento, Pundit, erro padrao e correlation id existem" ".docs/tasks-roadmap-v1.md" test_f0_error_auth_isolation
run_case "F0-12" "fase-0" "event recorder e log sanitizer minimizam dados sensiveis" ".docs/contratos-produto.md" test_f0_event_recorder_and_sanitizer
