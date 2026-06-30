import { expect, type Page, type Route, test } from "@playwright/test";

test.describe("cadastro login onboarding primeira sessao desktop mobile", () => {
  test("faz cadastro, mostra sessao inicial e conclui onboarding", async ({
    page,
  }) => {
    await mockApi(page);
    await page.goto("/");

    await expect(page.getByRole("heading", { name: "Orb" })).toBeVisible();
    await page.getByLabel("Nome").fill("Ana");
    await page.getByLabel("Email").fill("ana@example.com");
    await page.getByLabel("Senha").fill("senha-segura-123");
    await page.locator("form").getByRole("button", { name: "Criar conta" }).click();

    await expect(
      page.getByRole("heading", { name: "O que eu faco agora?" }),
    ).toBeVisible();
    await expect(page.getByText("ana@example.com")).toBeVisible();

    await page.getByLabel("Titulo da tarefa").fill("Produzir relatorio");
    await page.getByRole("button", { name: "Criar tarefa" }).click();
    await expect(page.getByText("Tarefa criada e confirmada pelo servidor.")).toBeVisible();
    await expect(
      page.getByLabel("Tarefas ativas").getByText("Produzir relatorio"),
    ).toBeVisible();

    await page.getByLabel("Titulo do evento").fill("Bloco de foco");
    await page.getByRole("button", { name: "Criar evento" }).click();
    await expect(page.getByText("Evento criado e janela recalculada pelo servidor.")).toBeVisible();
    await expect(page.getByLabel("Eventos").getByText("Bloco de foco")).toBeVisible();
    await expect(page.getByRole("heading", { name: "Historico curto" })).toBeVisible();

    await page.getByRole("button", { name: "Criar check-in" }).click();
    await expect(page.getByText("Check-in criado pelo servidor.")).toBeVisible();
    await page.getByRole("button", { name: "Bom" }).click();
    await expect(page.getByText("Energia recalibrada pelo servidor.")).toBeVisible();
    await expect(page.getByRole("heading", { name: "Energia media" })).toBeVisible();
    await page.getByRole("button", { name: "Gerar proxima acao" }).click();
    await expect(
      page.getByText("Motor deterministico · sem LLM · energia media"),
    ).toBeVisible();
    const nextActionPanel = page.locator('[aria-labelledby="next-action-title"]');
    await expect(nextActionPanel.getByRole("button", { name: "Comecar" })).toBeVisible();
    await expect(nextActionPanel.getByRole("button", { name: "Adiar" })).toBeVisible();
    await expect(nextActionPanel.getByRole("button", { name: "Trocar" })).toBeVisible();
    await nextActionPanel.getByRole("button", { name: "Comecar" }).click();
    await expect(page.getByText("Proxima acao aceita e registrada.")).toBeVisible();
    await page.getByRole("button", { name: "Iniciar pausa" }).click();
    await expect(page.getByText("Intervencao iniciada com duracao previsivel.")).toBeVisible();
    await page.getByLabel("Feedback opcional").fill("ajudou");
    await page.getByRole("button", { name: "Finalizar intervencao" }).click();
    await expect(page.getByText("Intervencao finalizada e energia recalibrada.")).toBeVisible();

    await page.reload();
    await expect(page.getByText("Hoje")).toBeVisible();
    await expect(
      page.getByLabel("Tarefas ativas").getByText("Produzir relatorio"),
    ).toBeVisible();

    await page.getByRole("button", { name: "Completar onboarding" }).click();
    await expect(page.getByText("1 de 6")).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Explorar primeiro" }),
    ).toBeVisible();

    await page.keyboard.press("Tab");
    await expect(page.getByRole("button", { name: "Sessao" })).toBeFocused();

    await page.getByRole("button", { name: "Comecar" }).click();
    await page.getByLabel("Nome ou apelido").fill("Ana");
    await page.getByRole("button", { name: "Continuar" }).click();

    await page.getByLabel("Trabalho").check();
    await page.getByRole("button", { name: "Continuar" }).click();

    await page.getByRole("button", { name: "Continuar" }).click();

    await page.getByLabel("Barulho").check();
    await page.getByLabel("Bastante").check();
    await page.getByRole("button", { name: "Ver resultado" }).click();

    await expect(page.getByText("6 de 6")).toBeVisible();
    await expect(page.getByText("Perfil confirmado pelo servidor.")).toBeVisible();
    await expect(page.getByText("Arquetipo")).toBeVisible();
    await expect(page.getByText("Coruja Estrategica")).toBeVisible();
    await expect(page.getByRole("button", { name: "Criar tarefa" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Criar evento" })).toBeVisible();

    await page.getByRole("button", { name: "Criar tarefa" }).click();
    await page.getByLabel("Titulo da tarefa").fill("Separar primeira acao");
    await page.getByRole("button", { name: "Preparar rascunho" }).click();
    await expect(page.getByText("Rascunho preparado")).toBeVisible();
  });

  test("bloqueia senha fraca antes do cadastro", async ({ page }) => {
    await mockApi(page);
    await page.goto("/");

    await page.getByLabel("Nome").fill("Henrique");
    await page.getByLabel("Email").fill("henrique@example.com");
    await page.getByLabel("Senha").fill("1234");
    await page.locator("form").getByRole("button", { name: "Criar conta" }).click();

    await expect(
      page.getByText("Use uma senha com pelo menos 12 caracteres"),
    ).toBeVisible();
    await expect(page.getByRole("heading", { name: "Orb" })).toBeVisible();
  });

  test("faz login e permite explorar primeiro sem bloquear resultado", async ({
    page,
  }) => {
    await mockApi(page);
    await page.goto("/");

    await page.getByRole("tab", { name: "Entrar" }).click();
    await page.getByLabel("Email").fill("ana@example.com");
    await page.getByLabel("Senha").fill("senha-segura-123");
    await page.locator("form").getByRole("button", { name: "Entrar" }).click();

    await expect(page.getByText("Hoje")).toBeVisible();
    await page.getByRole("button", { name: "Completar onboarding" }).click();
    await page.getByRole("button", { name: "Explorar primeiro" }).click();

    await expect(page.getByText("6 de 6")).toBeVisible();
    await expect(page.getByText("Explorador Versatil")).toBeVisible();
    await expect(page.getByRole("button", { name: "Criar evento" })).toBeVisible();
  });

  test("usuario com onboarding concluido entra direto no app", async ({ page }) => {
    await mockApi(page, { onboardingState: "concluido" });
    await page.goto("/");

    await page.getByRole("tab", { name: "Entrar" }).click();
    await page.getByLabel("Email").fill("henrique@example.com");
    await page.getByLabel("Senha").fill("senha-segura-123");
    await page.locator("form").getByRole("button", { name: "Entrar" }).click();

    await expect(
      page.getByRole("heading", { name: "O que eu faco agora?" }),
    ).toBeVisible();
    await expect(page.getByText("concluido")).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Completar onboarding" }),
    ).toHaveCount(0);
    await expect(
      page.getByRole("button", { name: "Retomar onboarding" }),
    ).toHaveCount(0);
  });

  test("mostra estado online-only recuperavel quando a API falha", async ({
    page,
  }) => {
    await mockApi(page, { failNextActionOnce: true });
    await page.goto("/");

    await page.getByRole("tab", { name: "Entrar" }).click();
    await page.getByLabel("Email").fill("ana@example.com");
    await page.getByLabel("Senha").fill("senha-segura-123");
    await page.locator("form").getByRole("button", { name: "Entrar" }).click();

    await expect(page.getByRole("heading", { name: "O que eu faco agora?" })).toBeVisible();
    await page.getByRole("button", { name: "Gerar proxima acao" }).click();
    await expect(page.getByText("Sem conexao com a API. Tente novamente.")).toBeVisible();
    await page.getByRole("button", { name: "Tentar novamente" }).click();
    await expect(page.getByRole("heading", { name: "O que eu faco agora?" })).toBeVisible();
  });
});

async function mockApi(
  page: Page,
  options: {
    failCoreOnce?: boolean;
    failNextActionOnce?: boolean;
    onboardingState?: "nao_iniciado" | "em_andamento" | "pulado" | "concluido";
  } = {},
) {
  let authenticated = false;
  let failCoreOnce = options.failCoreOnce ?? false;
  let failNextActionOnce = options.failNextActionOnce ?? false;
  const onboardingState = options.onboardingState ?? "nao_iniciado";
  const tasks: Array<Record<string, unknown>> = [];
  const events: Array<Record<string, unknown>> = [];
  const checkIns: Array<Record<string, unknown>> = [];
  const interventions: Array<Record<string, unknown>> = [];
  const history: Array<Record<string, unknown>> = [];
  let energy: Record<string, unknown> | null = null;

  await page.route("**/api/v1/auth/session", async (route) => {
    const method = route.request().method();

    if (method === "DELETE") {
      authenticated = false;
      await route.fulfill({ status: 204 });
      return;
    }

    if (!authenticated) {
      await route.fulfill({
        status: 401,
        json: {
          error: {
            code: "authentication_required",
            message: "Entre na sua conta para continuar.",
            details: [],
            correlation_id: "cor_e2e_session",
          },
        },
      });
      return;
    }

    await route.fulfill({ status: 200, json: sessionResponse(onboardingState) });
  });

  await page.route("**/api/v1/auth/sign_up", async (route) => {
    authenticated = true;
    await route.fulfill({
      status: 201,
      headers: {
        "Set-Cookie":
          "_orb_session=orb_session_e2e; Path=/; HttpOnly; SameSite=Lax",
      },
      json: sessionResponse(onboardingState),
    });
  });

  await page.route("**/api/v1/auth/login", async (route) => {
    authenticated = true;
    await route.fulfill({
      status: 200,
      headers: {
        "Set-Cookie":
          "_orb_session=orb_session_e2e; Path=/; HttpOnly; SameSite=Lax",
      },
      json: sessionResponse(onboardingState),
    });
  });

  await page.route("**/api/v1/onboarding/complete", async (route) => {
    await route.fulfill({
      status: 201,
      json: onboardingResponse("onboarding_concluido"),
    });
  });

  await page.route("**/api/v1/onboarding/skip", async (route) => {
    await route.fulfill({
      status: 201,
      json: onboardingResponse("onboarding_pulado"),
    });
  });

  await page.route("**/api/v1/tasks", async (route) => {
    const method = route.request().method();

    if (method === "GET") {
      if (failCoreOnce) {
        failCoreOnce = false;
        await route.fulfill({
          status: 503,
          json: {
            error: {
              code: "api_unavailable",
              message: "Sem conexao com a API. Tente novamente.",
              details: [],
              correlation_id: "cor_e2e_api_unavailable",
            },
          },
        });
        return;
      }

      await route.fulfill({
        status: 200,
        json: { version: 1, tasks, correlation_id: "cor_e2e_tasks" },
      });
      return;
    }

    const body = await route.request().postDataJSON();
    const task = taskResponse({
      id: `tsk_e2e_${tasks.length + 1}`,
      titulo: body.task.titulo,
      categoria: body.task.categoria,
      peso: body.task.peso,
      status: body.task.status ?? "nao_iniciado",
    });
    tasks.unshift(task);
    history.unshift(historyEntry("tarefa_criada", "tarefa", task.id, task.titulo));

    await route.fulfill({
      status: 201,
      json: { version: 1, task, correlation_id: "cor_e2e_task_create" },
    });
  });

  await page.route("**/api/v1/tasks/*", async (route) => {
    const id = route.request().url().split("/").pop() ?? "";
    const index = tasks.findIndex((task) => task.id === id);

    if (index === -1) {
      await route.fulfill({ status: 404, json: notFound() });
      return;
    }

    if (route.request().method() === "DELETE") {
      history.unshift(historyEntry("tarefa_excluida", "tarefa", id));
      tasks.splice(index, 1);
      await route.fulfill({ status: 204 });
      return;
    }

    const body = await route.request().postDataJSON();
    tasks[index] = { ...tasks[index], ...normalizeTaskChanges(body.changes) };
    history.unshift(historyEntry("tarefa_atualizada", "tarefa", id, String(tasks[index].titulo)));

    await route.fulfill({
      status: 200,
      json: { version: 1, task: tasks[index], correlation_id: "cor_e2e_task_update" },
    });
  });

  await page.route("**/api/v1/events**", async (route) => {
    const url = route.request().url();

    if (url.includes("/api/v1/events/")) {
      await handleEventMemberRoute(route, events, history);
      return;
    }

    if (route.request().method() === "GET") {
      await route.fulfill({
        status: 200,
        json: {
          version: 1,
          events,
          available_window_minutes: events.length > 0 ? 40 : null,
          correlation_id: "cor_e2e_events",
        },
      });
      return;
    }

    const body = await route.request().postDataJSON();
    const event = eventResponse({
      id: `evt_e2e_${events.length + 1}`,
      titulo: body.event.titulo,
      inicio: body.event.inicio,
      fim: body.event.fim,
      timezone: body.event.timezone,
      categoria: body.event.categoria,
    });
    events.push(event);
    history.unshift(historyEntry("evento_criado", "evento", event.id, event.titulo));

    await route.fulfill({
      status: 201,
      json: { version: 1, event, correlation_id: "cor_e2e_event_create" },
    });
  });

  await page.route("**/api/v1/energy/current", async (route) => {
    if (!energy) {
      await route.fulfill({ status: 404, json: notFound() });
      return;
    }

    await route.fulfill({
      status: 200,
      json: { version: 1, energy, correlation_id: "cor_e2e_energy" },
    });
  });

  await page.route("**/api/v1/check_ins/*/responses", async (route) => {
    const id = route.request().url().split("/").at(-2) ?? "";
    const index = checkIns.findIndex((checkIn) => checkIn.id === id);

    if (index === -1) {
      await route.fulfill({ status: 404, json: notFound() });
      return;
    }

    const body = await route.request().postDataJSON();
    const resposta = body.response.resposta;
    checkIns[index] = {
      ...checkIns[index],
      resposta: resposta === "prefiro_responder_depois" ? null : resposta,
      horario_respondido:
        resposta === "prefiro_responder_depois" ? null : "2026-06-14T12:15:00Z",
      adiamentos:
        resposta === "prefiro_responder_depois"
          ? Number(checkIns[index].adiamentos) + 1
          : checkIns[index].adiamentos,
    };

    if (resposta === "prefiro_responder_depois") {
      await route.fulfill({
        status: 200,
        json: {
          version: 1,
          status: "adiado",
          check_in: checkIns[index],
          energy: null,
          events: [{ event_type: "check_in_adiado" }],
          daily_limit: dailyLimit(checkIns.length),
          correlation_id: "cor_e2e_check_postpone",
          privacy_level: "sensivel",
        },
      });
      return;
    }

    energy = energyResponse("media", 72, "check_in");
    history.unshift(historyEntry("check_in_respondido", "check_in", id));
    history.unshift(historyEntry("energia_recalibrada", "energia", "eng_e2e"));

    await route.fulfill({
      status: 201,
      json: {
        version: 1,
        status: "respondido",
        check_in: checkIns[index],
        energy,
        events: [
          { event_type: "check_in_respondido" },
          { event_type: "energia_recalibrada" },
        ],
        daily_limit: dailyLimit(checkIns.length),
        correlation_id: "cor_e2e_check_response",
        privacy_level: "sensivel",
      },
    });
  });

  await page.route("**/api/v1/check_ins", async (route) => {
    if (route.request().method() === "GET") {
      await route.fulfill({
        status: 200,
        json: {
          version: 1,
          check_ins: checkIns,
          daily_limit: dailyLimit(checkIns.length),
          correlation_id: "cor_e2e_checkins",
          privacy_level: "sensivel",
        },
      });
      return;
    }

    const checkIn = checkInResponse(`chk_e2e_${checkIns.length + 1}`);
    checkIns.unshift(checkIn);
    history.unshift(historyEntry("check_in_criado", "check_in", checkIn.id));

    await route.fulfill({
      status: 201,
      json: {
        version: 1,
        check_in: checkIn,
        daily_limit: dailyLimit(checkIns.length),
        correlation_id: "cor_e2e_checkin_create",
        privacy_level: "sensivel",
      },
    });
  });

  await page.route("**/api/v1/suggestions/next_action", async (route) => {
    if (failNextActionOnce) {
      failNextActionOnce = false;
      await route.fulfill({
        status: 503,
        json: {
          error: {
            code: "api_unavailable",
            message: "Sem conexao com a API. Tente novamente.",
            details: [],
            correlation_id: "cor_e2e_next_action_unavailable",
          },
        },
      });
      return;
    }

    const firstTask = tasks[0] ?? taskResponse({ id: "nova", titulo: "Nova tarefa" });

    await route.fulfill({
      status: 200,
      json: {
        version: 1,
        suggestion_id: "sug_e2e_1",
        source: "web",
        correlation_id: "cor_e2e_next_action",
        privacy_level: "sensivel",
        decision_engine: "deterministico",
        action: { type: "comecar", resource: { type: "tarefa", id: firstTask.id } },
        reason:
          "Cabe na janela atual e tem peso compativel com a energia confirmada pelo servidor.",
        actions_available: ["comecar", "adiar", "trocar"],
        explanation_inputs: {
          energia_estado: "media",
          janela_disponivel_minutos: 40,
          task_weight: "medio",
        },
        llm_used: false,
        fallback_available: true,
      },
    });
  });

  await page.route("**/api/v1/suggestions/*/actions", async (route) => {
    const body = await route.request().postDataJSON();
    const action = body.suggestion_action.action;

    history.unshift(historyEntry(`sugestao_${action}`, "sugestao", "sug_e2e_1"));
    await route.fulfill({
      status: 200,
      json: {
        version: 1,
        suggestion_id: "sug_e2e_1",
        action_taken: action,
        event: { event_type: action === "trocar" ? "sugestao_trocada" : "sugestao_aceita" },
        correlation_id: "cor_e2e_suggestion_action",
        privacy_level: "sensivel",
      },
    });
  });

  await page.route("**/api/v1/interventions**", async (route) => {
    const url = route.request().url();

    if (url.includes("/api/v1/interventions/")) {
      await handleInterventionMemberRoute(route, interventions, history, (nextEnergy) => {
        energy = nextEnergy;
      });
      return;
    }

    if (route.request().method() === "GET") {
      await route.fulfill({
        status: 200,
        json: {
          version: 1,
          interventions,
          correlation_id: "cor_e2e_interventions",
          privacy_level: "sensivel",
        },
      });
      return;
    }

    const intervention = interventionResponse(`int_e2e_${interventions.length + 1}`);
    interventions.unshift(intervention);
    history.unshift(historyEntry("intervencao_iniciada", "intervencao", intervention.id));

    await route.fulfill({
      status: 201,
      json: {
        version: 1,
        intervention,
        events: [{ event_type: "intervencao_iniciada" }],
        correlation_id: "cor_e2e_intervention_start",
        privacy_level: "sensivel",
      },
    });
  });

  await page.route("**/api/v1/history", async (route) => {
    if (failCoreOnce) {
      failCoreOnce = false;
      await route.fulfill({
        status: 503,
        json: {
          error: {
            code: "api_unavailable",
            message: "Sem conexao com a API. Tente novamente.",
            details: [],
            correlation_id: "cor_e2e_api_unavailable",
          },
        },
      });
      return;
    }

    await route.fulfill({
      status: 200,
      json: {
        version: 1,
        history,
        entitlement: {
          plan: "free",
          history_window_days: 14,
          full_history: false,
          downgrade_behavior:
            "downgrade_preserva_dados_e_oculta_historico_fora_do_plano",
        },
        correlation_id: "cor_e2e_history",
        privacy_level: "interno",
      },
    });
  });
}

function sessionResponse(
  onboardingState: "nao_iniciado" | "em_andamento" | "pulado" | "concluido" = "nao_iniciado",
) {
  return {
    version: 1,
    user: {
      version: 1,
      id: "usr_e2e",
      nome: "Ana",
      email: "ana@example.com",
      pronomes: null,
      timezone: "America/Sao_Paulo",
      idioma: "pt-BR",
      plano_atual: "free",
      status_conta: "ativa",
      onboarding: {
        state: onboardingState,
        current_step: onboardingState === "concluido" ? 6 : null,
        total_steps: 6,
        resume_available: onboardingState === "em_andamento" || onboardingState === "pulado",
      },
      privacy_level: "interno",
      created_at: "2026-06-14T12:00:00Z",
      updated_at: "2026-06-14T12:00:00Z",
    },
    session: {
      authenticated: true,
      transport: "cookie",
      expires_at: "2026-07-14T12:00:00Z",
      source: "web",
    },
    correlation_id: "cor_e2e_auth",
    privacy_level: "interno",
  };
}

function taskResponse({
  categoria = "trabalho",
  id,
  peso = "medio",
  status = "nao_iniciado",
  titulo,
}: {
  categoria?: unknown;
  id: string;
  peso?: unknown;
  status?: unknown;
  titulo: unknown;
}) {
  return {
    version: 1,
    id,
    usuario_id: "usr_e2e",
    organizacao_id: null,
    titulo,
    categoria,
    prazo: null,
    duracao_estimada_minutos: 45,
    peso,
    status,
    origem: "usuario",
    responsavel_id: "usr_e2e",
    contexto_resumido: null,
    micro_passo_id: null,
    privacy_level: "interno",
    created_at: "2026-06-14T12:00:00Z",
    updated_at: "2026-06-14T12:00:00Z",
  };
}

function checkInResponse(id: string) {
  return {
    version: 1,
    id,
    usuario_id: "usr_e2e",
    tipo: "estado_energia",
    pergunta_id: "q_estado_energia_v1",
    resposta: null,
    horario_previsto: "08:00",
    horario_respondido: null,
    timezone: "America/Sao_Paulo",
    adiamentos: 0,
    origem: "manual",
    source: "web",
    privacy_level: "sensivel",
    created_at: "2026-06-14T12:10:00Z",
  };
}

function energyResponse(
  estado: "alta" | "media" | "baixa" | "em_recuperacao" | "em_sobrecarga",
  valor: number,
  fonte: "check_in" | "intervencao",
) {
  return {
    version: 1,
    id: "eng_e2e",
    usuario_id: "usr_e2e",
    valor,
    estado_qualitativo: estado,
    fonte_calibracao: fonte,
    confianca: "media",
    timestamp: "2026-06-14T12:15:00Z",
    fatores: [fonte === "check_in" ? "resposta_check_in" : "intervencao_finalizada"],
    source: "web",
    privacy_level: "sensivel",
  };
}

function dailyLimit(used: number) {
  return {
    plan: "free",
    limit: 2,
    used,
    remaining: Math.max(2 - used, 0),
    period: "dia",
    resets_at: "2026-06-15T03:00:00Z",
    enforced_by: "server",
  };
}

function interventionResponse(id: string) {
  return {
    version: 1,
    id,
    usuario_id: "usr_e2e",
    tipo: "respiracao_guiada",
    gatilho: "sobrecarga",
    duracao_prevista_minutos: 3,
    inicio: "2026-06-14T12:20:00Z",
    fim: null,
    efeito_estimado: null,
    feedback: null,
    source: "web",
    privacy_level: "sensivel",
  };
}

function eventResponse({
  categoria = "trabalho",
  fim,
  id,
  inicio,
  timezone,
  titulo,
}: {
  categoria?: unknown;
  fim: unknown;
  id: string;
  inicio: unknown;
  timezone: unknown;
  titulo: unknown;
}) {
  return {
    version: 1,
    id,
    usuario_id: "usr_e2e",
    organizacao_id: null,
    titulo,
    inicio,
    fim,
    timezone,
    categoria,
    peso: "leve",
    status: "confirmado",
    recorrencia: null,
    origem: "usuario",
    external_ref: null,
    privacy_level: "interno",
    created_at: "2026-06-14T12:00:00Z",
    updated_at: "2026-06-14T12:00:00Z",
  };
}

async function handleEventMemberRoute(
  route: Route,
  events: Array<Record<string, unknown>>,
  history: Array<Record<string, unknown>>,
) {
  const id = route.request().url().split("/").pop() ?? "";
  const index = events.findIndex((event) => event.id === id);

  if (index === -1) {
    await route.fulfill({ status: 404, json: notFound() });
    return;
  }

  if (route.request().method() === "DELETE") {
    history.unshift(historyEntry("evento_excluido", "evento", id));
    events.splice(index, 1);
    await route.fulfill({ status: 204 });
    return;
  }

  const body = await route.request().postDataJSON();
  events[index] = { ...events[index], ...normalizeEventChanges(body.changes) };
  history.unshift(historyEntry("evento_atualizado", "evento", id, String(events[index].titulo)));

  await route.fulfill({
    status: 200,
    json: { version: 1, event: events[index], correlation_id: "cor_e2e_event_update" },
  });
}

async function handleInterventionMemberRoute(
  route: Route,
  interventions: Array<Record<string, unknown>>,
  history: Array<Record<string, unknown>>,
  setEnergy: (energy: Record<string, unknown>) => void,
) {
  const id = route.request().url().split("/").pop() ?? "";
  const index = interventions.findIndex((intervention) => intervention.id === id);

  if (index === -1) {
    await route.fulfill({ status: 404, json: notFound() });
    return;
  }

  const body = await route.request().postDataJSON();
  interventions[index] = {
    ...interventions[index],
    fim: "2026-06-14T12:23:00Z",
    efeito_estimado: "recuperacao_leve",
    feedback: body.intervention.feedback ?? null,
  };
  const nextEnergy = energyResponse("em_recuperacao", 58, "intervencao");
  setEnergy(nextEnergy);
  history.unshift(historyEntry("intervencao_finalizada", "intervencao", id));
  history.unshift(historyEntry("energia_recalibrada", "energia", "eng_e2e_2"));

  await route.fulfill({
    status: 200,
    json: {
      version: 1,
      intervention: interventions[index],
      energy: nextEnergy,
      events: [
        { event_type: "intervencao_finalizada" },
        { event_type: "energia_recalibrada" },
      ],
      correlation_id: "cor_e2e_intervention_finish",
      privacy_level: "sensivel",
    },
  });
}

function normalizeTaskChanges(changes: Record<string, unknown>) {
  return compactRecord({
    titulo: changes.titulo,
    status: changes.status,
  });
}

function normalizeEventChanges(changes: Record<string, unknown>) {
  return compactRecord({
    titulo: changes.titulo,
  });
}

function compactRecord(record: Record<string, unknown>) {
  return Object.fromEntries(
    Object.entries(record).filter(([, value]) => value !== undefined),
  );
}

function historyEntry(
  eventType: string,
  kind: string,
  id: unknown,
  titulo?: string,
) {
  return {
    version: 1,
    kind,
    event_type: eventType,
    occurred_at: "2026-06-14T12:00:00Z",
    resource: { type: kind, id },
    source: "web",
    correlation_id: "cor_e2e_history_event",
    privacy_level: "interno",
    summary: titulo ? { titulo, status: "registrado" } : { tombstone: true },
  };
}

function notFound() {
  return {
    error: {
      code: "not_found",
      message: "Recurso nao encontrado.",
      details: [],
      correlation_id: "cor_e2e_not_found",
    },
  };
}

function onboardingResponse(
  state: "onboarding_concluido" | "onboarding_pulado",
) {
  const skipped = state === "onboarding_pulado";

  return {
    version: 1,
    onboarding_state: state,
    source: "web",
    correlation_id: skipped ? "cor_e2e_skip" : "cor_e2e_complete",
    privacy_level: "sensivel",
    default_profile_created: skipped,
    resume_available: skipped,
    perfil_energetico: {
      version: 1,
      usuario_id: "usr_e2e",
      arquetipo: skipped ? "Explorador Versatil" : "Coruja Estrategica",
      objetivo_principal: skipped ? "rotina_geral" : "trabalho",
      janelas_pico: skipped ? [] : ["noite"],
      janelas_baixa_energia: skipped ? [] : ["depois_do_almoco"],
      gatilhos: skipped ? [] : ["barulho"],
      identificacoes_neurodivergentes: [],
      tom_preferido: "acolhedor",
      sensibilidade: skipped ? "media" : "alta",
      intensidade_notificacao: "equilibrado",
      horario_primeiro_check_in: "08:00",
      horario_ultimo_check_in: "18:00",
      horarios_refeicoes: [],
      pausas_protegidas: [],
      confianca: skipped ? "baixa" : "media",
      data_onboarding: "2026-06-14T12:00:00Z",
      decision_engine: "deterministico",
      llm_used: false,
      source: "web",
      privacy_level: "sensivel",
      updated_at: "2026-06-14T12:00:00Z",
    },
    energia: {
      estado_qualitativo: "media",
      confianca: skipped ? "baixa" : "media",
    },
    event: {
      event_type: state,
    },
    first_action: {
      type: "create_first_task_or_event",
      status: "offered",
      actions: ["criar_tarefa", "criar_evento"],
    },
  };
}
