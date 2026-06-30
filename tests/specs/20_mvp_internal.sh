#!/usr/bin/env bash

test_mvp_01_build_initial_profile() {
  assert_any_file_contains "$ROOT_DIR/api" 'BuildInitialProfile|perfil_energetico_inicial' "Servico de perfil inicial deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'Coruja Estrategica|Cotovia Focada|Pendulo Versatil|Explorador' "Arquetipo deve ser gerado por regra deterministica"
  assert_no_file_contains "$ROOT_DIR/api" 'llm.*arquetipo|arquetipo.*llm|generate_profile_with_llm' "Onboarding e arquetipo nao podem depender de LLM"
}

test_mvp_02_complete_flow_summary() {
  assert_any_file_contains "$ROOT_DIR/api" 'CompleteFlow|onboarding_concluido' "Fluxo resumido deve concluir onboarding"
  assert_any_file_contains "$ROOT_DIR/api" 'perfil_energetico|energia|first_action|onboarding_concluido' "CompleteFlow deve retornar perfil, energia, evento e primeira acao"
  assert_any_file_contains "$ROOT_DIR/api" 'flow_variant.*resumido|resumido' "Fluxo MVP deve ser resumido"
}

test_mvp_03_skip_flow() {
  assert_any_file_contains "$ROOT_DIR/api" 'SkipFlow|onboarding_pulado|explorar_primeiro' "Fluxo de skip deve criar perfil provisorio"
  assert_any_file_contains "$ROOT_DIR/api" 'baixa_confianca|confianca.*baixa|baixa' "Skip deve iniciar energia media com confianca baixa"
  assert_any_file_contains "$ROOT_DIR/api" 'resume_available|retomada|retomar' "Skip deve permitir retomada"
}

test_mvp_04_onboarding_progress() {
  assert_any_file_contains "$ROOT_DIR/api" 'nao_iniciado|em_andamento|pulado|concluido|revisao_solicitada' "Estados oficiais de onboarding devem existir"
  assert_any_file_contains "$ROOT_DIR/api" 'onboarding_progress|PersistProgress|current_step' "Progresso de onboarding deve ser persistido para retomada"
  assert_any_file_contains "$ROOT_DIR/api" 'onboarding_started_at|onboarding_completed_at|onboarding_skipped_at' "Datas de progresso devem existir"
}

test_mvp_05_complete_endpoint() {
  assert_any_file_contains "$ROOT_DIR/api" 'POST.*/onboarding/complete|onboarding/complete|OnboardingController' "Endpoint POST /onboarding/complete deve existir"
  assert_any_file_contains "$ROOT_DIR/api/spec" 'POST /api/v1/onboarding/complete|onboarding/complete' "Request spec de complete deve existir"
  assert_any_file_contains "$ROOT_DIR/packages/contracts" '/api/v1/onboarding/complete|onboarding_complete_response' "Contrato/fixture de complete deve existir"
}

test_mvp_06_skip_endpoint() {
  assert_any_file_contains "$ROOT_DIR/api" 'POST.*/onboarding/skip|onboarding/skip|OnboardingController' "Endpoint POST /onboarding/skip deve existir"
  assert_any_file_contains "$ROOT_DIR/api/spec" 'POST /api/v1/onboarding/skip|onboarding/skip' "Request spec de skip deve existir"
  assert_any_file_contains "$ROOT_DIR/packages/contracts" '/api/v1/onboarding/skip|onboarding_skip_response' "Contrato/fixture de skip deve existir"
}

test_mvp_07_web_onboarding_summary() {
  assert_any_file_contains "$ROOT_DIR/apps/web" '1 de 6|1 de 12' "UI de onboarding deve mostrar progresso"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'Explorar primeiro|Voltar|Comecar|Começar' "UI deve ter voltar, inicio e skip"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'aria-label|role=|tabIndex|focus-visible' "Onboarding web deve nascer acessivel por teclado/leitor"
}

test_mvp_08_profile_result() {
  assert_any_file_contains "$ROOT_DIR/apps/web" 'Coruja Estrategica|Cotovia Focada|Pendulo Versatil|Explorador' "Tela de resultado deve mostrar arquetipo"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'curva|Orb inicial|perfil inicial|Perfil Energetico' "Tela de resultado deve mostrar curva/Orb inicial"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'Criar tarefa|Criar evento' "Resultado deve oferecer primeira tarefa/evento"
}

test_mvp_09_neurodivergence_policy() {
  assert_any_file_contains "$ROOT_DIR/api" 'NeurodivergenceUsePolicy|identificacoes_neurodivergentes|neurodivergent_identifications' "Policy de uso de neurodivergencia deve existir"
  assert_any_file_contains "$ROOT_DIR/api/spec" 'preco|pricing|feature_access|ranking|third_party|billing' "Spec deve bloquear preco, acesso, ranking, terceiros e billing"
  assert_no_file_contains "$ROOT_DIR/api" 'neurodiverg.*preco|preco.*neurodiverg|neurodiverg.*ranking|ranking.*neurodiverg' "Neurodivergencia nao pode afetar preco/ranking"
}

test_mvp_tasks_contract() {
  assert_any_file_contains "$ROOT_DIR/api" 'TasksController|TarefasController|class Task|class Tarefa' "CRUD de tarefa individual deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'ApplyUpdate|partial_update|changes' "Update parcial deve preservar campos omitidos"
  assert_any_file_contains "$ROOT_DIR/api" 'soft_delete|tarefa_excluida|deleted_at' "Soft delete/tombstone de tarefa deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'user_id|usuario_id' "Tarefa deve pertencer ao usuario autenticado"
}

test_mvp_events_contract() {
  assert_any_file_contains "$ROOT_DIR/api" 'EventsController|EventosController|class Event|class Evento' "CRUD de evento individual deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'inicio|starts_at|fim|ends_at|timezone' "Evento deve ser ancorado em inicio, fim e timezone"
  assert_any_file_contains "$ROOT_DIR/api" 'external_ref|origem.*integration|origem.*externa' "Evento externo deve registrar origem/ref externa"
  assert_any_file_contains "$ROOT_DIR/api" 'consentimento|consent|read_only|leitura' "Escrita em calendario externo deve exigir consentimento"
}

test_mvp_history_by_entitlement() {
  assert_any_file_contains "$ROOT_DIR/api" 'History|Historico|Timeline' "Historico curto deve existir"
  assert_any_file_contains "$ROOT_DIR/api" '14.*dias|14.days|free.*14' "Free deve ver historico de 14 dias"
  assert_any_file_contains "$ROOT_DIR/api" 'downgrade.*nao.*apaga|downgrade.*preserv|hide.*not.*delete' "Downgrade deve esconder, nao apagar dados"
}

test_mvp_checkins_energy() {
  assert_any_file_contains "$ROOT_DIR/api" 'DailyLimit|check.*limit|limite.*check' "Limite diario de check-in deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'free.*2|2.*free' "Free deve ter 2 check-ins/dia"
  assert_any_file_contains "$ROOT_DIR/api" 'pro.*5|5.*pro' "Pro deve ter 5 check-ins/dia"
  assert_any_file_contains "$ROOT_DIR/api" 'check_in_respondido|energia_recalibrada' "Resposta de check-in deve recalibrar energia e emitir eventos"
  assert_any_file_contains "$ROOT_DIR/api" 'alta|media|baixa|em_recuperacao|em_sobrecarga' "Estados oficiais de energia devem ser validados"
  assert_any_file_contains "$ROOT_DIR/api" 'reason_codes|motor_deterministico_v1|delta_check_in' "Energia deve expor reason codes controlados"
}

test_mvp_next_action_engine() {
  assert_any_file_contains "$ROOT_DIR/api" 'NextAction|ProximaAcao|suggestions/next_action' "Motor de proxima acao deve existir"
  assert_any_file_contains "$ROOT_DIR/api" 'comecar|adiar|trocar' "Sugestao deve oferecer comecar, adiar e trocar"
  assert_any_file_contains "$ROOT_DIR/api" 'janela_disponivel|available_window|proximo_evento' "Motor deve considerar janela ate proximo evento"
  assert_any_file_contains "$ROOT_DIR/api" 'em_sobrecarga|em_recuperacao|regulacao|pausa' "Motor deve proteger sobrecarga/recuperacao com regulacao"
  assert_any_file_contains "$ROOT_DIR/api" 'score|drenagem_prevista|predicted_drain|reason_codes' "Motor deve explicar score e drenagem prevista sem LLM"
  assert_no_file_contains "$ROOT_DIR/api" 'IA decidiu|AI decided|llm_decided' "Motivo de sugestao nao pode dizer que IA decidiu"
}

test_mvp_interventions() {
  assert_any_file_contains "$ROOT_DIR/api" 'InterventionsController|IntervencoesController|class Intervention|class Intervencao' "Intervencoes devem existir"
  assert_any_file_contains "$ROOT_DIR/api" 'intervencao_iniciada|intervencao_finalizada|energia_recalibrada' "Intervencao deve emitir eventos e recalibrar energia"
  assert_any_file_contains "$ROOT_DIR/api" 'timer|duracao|duration' "Intervencao deve ter duracao previsivel"
  assert_file_not_contains "$ROOT_DIR/api/app/controllers/api/v1/interventions_controller.rb" 'ranking|moeda_virtual|streak.*zero' "Regulacao nao pode usar ranking/moeda/streak punitivo"
  assert_file_not_contains "$ROOT_DIR/api/app/models/intervention.rb" 'ranking|moeda_virtual|streak.*zero' "Regulacao nao pode usar ranking/moeda/streak punitivo"
  assert_no_file_contains "$ROOT_DIR/api/app/services/interventions" 'ranking|moeda_virtual|streak.*zero' "Regulacao nao pode usar ranking/moeda/streak punitivo"
}

test_mvp_first_session_e2e() {
  assert_dir_exists "$ROOT_DIR/apps/web/e2e" "E2E web deve existir"
  assert_any_file_contains "$ROOT_DIR/apps/web/e2e" 'signup|cadastro|onboarding|check.?in|next.?action|proxima.?acao' "E2E deve cobrir signup, onboarding, check-in e proxima acao"
  assert_any_file_contains "$ROOT_DIR/apps/web/e2e" 'mobile|desktop|viewport' "E2E deve rodar em desktop e mobile"
  assert_any_file_contains "$ROOT_DIR/apps/web" 'tentar novamente|sem conexao|online-only|conexao' "Falha online-only deve ser clara e recuperavel"
}

run_case "MVP-01" "mvp" "BuildInitialProfile gera perfil e arquetipo sem LLM" ".docs/onboarding.md" test_mvp_01_build_initial_profile
run_case "MVP-02" "mvp" "CompleteFlow resumido retorna perfil, energia, evento e primeira acao" ".docs/tasks-roadmap-v1.md" test_mvp_02_complete_flow_summary
run_case "MVP-03" "mvp" "SkipFlow cria defaults suaves com retomada" ".docs/onboarding.md" test_mvp_03_skip_flow
run_case "MVP-04" "mvp" "progresso de onboarding e estados oficiais persistem" ".docs/onboarding.md" test_mvp_04_onboarding_progress
run_case "MVP-05" "mvp" "endpoint POST /onboarding/complete existe com request spec e contrato" ".docs/tasks-roadmap-v1.md" test_mvp_05_complete_endpoint
run_case "MVP-06" "mvp" "endpoint POST /onboarding/skip existe com request spec e contrato" ".docs/tasks-roadmap-v1.md" test_mvp_06_skip_endpoint
run_case "MVP-07" "mvp" "web onboarding resumido mostra progresso, voltar, skip e acessibilidade" ".docs/onboarding.md" test_mvp_07_web_onboarding_summary
run_case "MVP-08" "mvp" "web resultado do perfil mostra arquetipo, curva e CTA inicial" ".docs/onboarding.md" test_mvp_08_profile_result
run_case "MVP-09" "mvp" "neurodivergencia opcional nao afeta preco, acesso, ranking ou terceiros" ".docs/privacidade-lgpd.md" test_mvp_09_neurodivergence_policy
run_case "MVP-10-12" "mvp" "tarefas têm CRUD, update parcial e soft delete" ".docs/contratos-produto.md" test_mvp_tasks_contract
run_case "MVP-13-16" "mvp" "eventos sao ancorados e calendario externo e read-only" ".docs/contratos-produto.md" test_mvp_events_contract
run_case "MVP-17" "mvp" "historico respeita entitlement sem apagar dados" ".docs/escopo-v1.md" test_mvp_history_by_entitlement
run_case "MVP-19-23" "mvp" "check-ins recalibram energia com limites Free/Pro" ".docs/requisitos-stack.md" test_mvp_checkins_energy
run_case "MVP-24-25" "mvp" "NextAction e deterministico e protege regulacao" ".docs/ml-llm.md" test_mvp_next_action_engine
run_case "MVP-26-27" "mvp" "intervencoes possuem timer, eventos e sem gamificacao punitiva" ".docs/definicao.md" test_mvp_interventions
run_case "MVP-28-29" "mvp" "primeira sessao E2E cobre valor central e online-only" ".docs/roadmap-cto.md" test_mvp_first_session_e2e
