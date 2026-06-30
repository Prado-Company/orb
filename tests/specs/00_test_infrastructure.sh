#!/usr/bin/env bash

test_infra_docs_available() {
  local docs=(
    ".docs/stack.md"
    ".docs/tasks-roadmap-v1.md"
    ".docs/roadmap-cto.md"
    ".docs/escopo-v1.md"
    ".docs/contratos-produto.md"
    ".docs/onboarding.md"
    ".docs/ml-llm.md"
    ".docs/privacidade-lgpd.md"
    ".docs/requisitos-stack.md"
    ".docs/runbooks-v1.md"
  )
  local doc
  for doc in "${docs[@]}"; do
    assert_file_exists "$ROOT_DIR/$doc" "Documentacao fonte obrigatoria para os testes"
  done
}

test_infra_reports_ignored() {
  assert_file_contains "$ROOT_DIR/.gitignore" '^test-reports/$' "Relatorios de teste devem ficar fora do commit"
  [[ ! -d "$ROOT_DIR/tests/reports" ]] || fail "Relatorios nao devem ser gerados dentro de /tests"
}

test_infra_runner_contract() {
  assert_file_exists "$ROOT_DIR/tests/run.sh" "Runner de testes deve existir em /tests"
  assert_file_contains "$ROOT_DIR/tests/run.sh" 'summary\.md' "Runner deve gerar relatorio Markdown"
  assert_file_contains "$ROOT_DIR/tests/run.sh" 'results\.json' "Runner deve gerar relatorio JSON"
  assert_file_contains "$ROOT_DIR/tests/run.sh" 'junit\.xml' "Runner deve gerar relatorio JUnit"
  assert_file_contains "$ROOT_DIR/tests/run.sh" 'red-first-todo\.md' "Runner deve gerar TODO red-first"
}

test_infra_todo_map_exists() {
  assert_file_exists "$ROOT_DIR/tests/TODO.md" "TODO de execucao TDD deve existir"
  assert_file_contains "$ROOT_DIR/tests/TODO.md" 'Fase 0 - Fundacao executavel' "TODO deve mapear Fase 0"
  assert_file_contains "$ROOT_DIR/tests/TODO.md" 'MVP interno' "TODO deve mapear MVP interno"
  assert_file_contains "$ROOT_DIR/tests/TODO.md" 'Beta privada' "TODO deve mapear Beta privada"
  assert_file_contains "$ROOT_DIR/tests/TODO.md" 'v1 publica' "TODO deve mapear v1 publica"
}

run_case "INFRA-01" "infra" "documentacao fonte esta disponivel" ".docs/*.md" test_infra_docs_available
run_case "INFRA-02" "infra" "relatorios sao gerados fora de /tests e ignorados pelo Git" ".docs/tasks-roadmap-v1.md" test_infra_reports_ignored
run_case "INFRA-03" "infra" "runner gera Markdown, JSON, JUnit e TODO red-first" ".docs/tasks-roadmap-v1.md" test_infra_runner_contract
run_case "INFRA-04" "infra" "TODO operacional cobre Fase 0 ate v1 publica" ".docs/tasks-roadmap-v1.md" test_infra_todo_map_exists
