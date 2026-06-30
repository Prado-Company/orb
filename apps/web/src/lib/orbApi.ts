export type OnboardingState =
  | "nao_iniciado"
  | "em_andamento"
  | "pulado"
  | "concluido"
  | "revisao_solicitada";

export type SessionUser = {
  version: 1;
  id: string;
  nome: string;
  email: string;
  pronomes?: string | null;
  timezone: string;
  idioma: string;
  plano_atual: "free" | "pro" | "teams";
  status_conta: string;
  onboarding?: {
    state: OnboardingState;
    current_step?: number | null;
    total_steps?: number | null;
    resume_available: boolean;
  };
  privacy_level: string;
  created_at: string;
  updated_at: string;
};

export type AuthSessionResponse = {
  version: 1;
  user: SessionUser;
  session: {
    authenticated: true;
    transport: "cookie";
    expires_at: string;
    source: "web";
  };
  correlation_id: string;
  privacy_level: "interno";
};

export type Objective =
  | "trabalho"
  | "estudo"
  | "casa_e_familia"
  | "autocuidado"
  | "transicao_de_carreira"
  | "rotina_geral";

export type Sensitivity = "baixa" | "media" | "alta";

export type OnboardingAnswers = {
  nome: string;
  timezone: string;
  idioma: "pt-BR";
  objetivo_principal: Objective;
  horario_primeiro_check_in: string;
  horario_ultimo_check_in: string;
  janelas_pico: string[];
  janelas_baixa_energia: string[];
  gatilhos: string[];
  sensibilidade: Sensitivity;
};

export type OnboardingResponse = {
  version: 1;
  onboarding_state: "onboarding_concluido" | "onboarding_pulado";
  source: "web";
  perfil_energetico?: {
    arquetipo?: string;
    confianca?: "baixa" | "media";
    data_onboarding?: string;
  };
  correlation_id: string;
  privacy_level: "sensivel";
};

export type TaskItem = {
  version: 1;
  id: string;
  usuario_id: string;
  titulo: string;
  categoria?: string | null;
  prazo?: string | null;
  duracao_estimada_minutos?: number | null;
  peso?: "leve" | "medio" | "pesado" | null;
  status: "nao_iniciado" | "em_progresso" | "concluido" | "adiado";
  origem: "usuario" | "orb" | "integration";
  responsavel_id?: string | null;
  contexto_resumido?: string | null;
  privacy_level: "interno" | "sensivel";
  created_at: string;
  updated_at: string;
};

export type EventItem = {
  version: 1;
  id: string;
  usuario_id: string;
  titulo: string;
  inicio: string;
  fim: string;
  timezone: string;
  categoria?: string | null;
  peso?: "leve" | "medio" | "pesado" | null;
  status: "confirmado" | "cancelado" | "concluido";
  origem: "usuario" | "integration";
  external_ref?: string | null;
  privacy_level: "interno" | "sensivel";
  created_at: string;
  updated_at: string;
};

export type HistoryEntry = {
  version: 1;
  kind: "tarefa" | "evento" | "check_in" | "energia" | "intervencao";
  event_type: string;
  occurred_at: string;
  resource: { type: string; id: string };
  privacy_level: "interno" | "sensivel";
  summary: Record<string, unknown>;
};

export type EnergyState =
  | "alta"
  | "media"
  | "baixa"
  | "em_recuperacao"
  | "em_sobrecarga";

export type EnergyItem = {
  version: 1;
  id?: string;
  usuario_id: string;
  valor: number;
  estado_qualitativo: EnergyState;
  fonte_calibracao: "onboarding" | "check_in" | "tarefa" | "intervencao" | "historico";
  confianca: "baixa" | "media" | "alta";
  timestamp: string;
  fatores: string[];
  source: "web" | "android" | "ios";
  privacy_level: "sensivel";
};

export type CheckInResponseValue =
  | "muito_baixo"
  | "baixo"
  | "neutro"
  | "bom"
  | "alto";

export type CheckInItem = {
  version: 1;
  id: string;
  usuario_id: string;
  tipo: string;
  pergunta_id: string;
  resposta: CheckInResponseValue | null;
  horario_previsto: string;
  horario_respondido?: string | null;
  timezone: string;
  adiamentos: number;
  origem: "programado" | "manual";
  source: "web" | "android" | "ios";
  privacy_level: "sensivel";
  created_at: string;
};

export type DailyLimit = {
  plan: "free" | "pro" | "teams";
  limit: number;
  used: number;
  remaining: number;
  period: "dia";
  resets_at: string;
  enforced_by: "server";
};

export type NextActionResponse = {
  version: 1;
  suggestion_id: string;
  source: "web";
  correlation_id: string;
  privacy_level: "sensivel";
  decision_engine: "deterministico";
  action: {
    type: "comecar" | "adiar" | "trocar" | "regular";
    resource: { type: string; id: string };
  };
  reason: string;
  actions_available: Array<"comecar" | "adiar" | "trocar">;
  explanation_inputs: {
    energia_estado: EnergyState;
    janela_disponivel_minutos: number;
    task_weight?: "leve" | "medio" | "pesado" | null;
  };
  llm_used: false;
  fallback_available: boolean;
};

export type InterventionItem = {
  version: 1;
  id: string;
  usuario_id: string;
  tipo: "respiracao_guiada" | "pausa_curta" | string;
  gatilho?: string | null;
  duracao_prevista_minutos: number;
  inicio: string;
  fim?: string | null;
  efeito_estimado?: string | null;
  feedback?: string | null;
  source: "web" | "android" | "ios";
  privacy_level: "sensivel";
};

export type TaskInput = {
  titulo: string;
  categoria?: string;
  prazo?: string;
  duracao_estimada_minutos?: number;
  peso?: "leve" | "medio" | "pesado";
  status?: TaskItem["status"];
  contexto?: string;
};

export type EventInput = {
  titulo: string;
  inicio: string;
  fim: string;
  timezone: string;
  categoria?: string;
  peso?: "leve" | "medio" | "pesado";
  status?: EventItem["status"];
};

export type TaskListResponse = {
  version: 1;
  tasks: TaskItem[];
  correlation_id: string;
};

export type EventListResponse = {
  version: 1;
  events: EventItem[];
  available_window_minutes?: number | null;
  correlation_id: string;
};

export type HistoryResponse = {
  version: 1;
  history: HistoryEntry[];
  entitlement: {
    plan: "free" | "pro" | "teams";
    history_window_days: number | null;
    full_history: boolean;
    downgrade_behavior: string;
  };
  correlation_id: string;
  privacy_level: "interno";
};

export type CurrentEnergyResponse = {
  version: 1;
  energy: EnergyItem;
  correlation_id: string;
};

export type CheckInListResponse = {
  version: 1;
  check_ins: CheckInItem[];
  daily_limit: DailyLimit;
  correlation_id: string;
  privacy_level: "sensivel";
};

export type CheckInCreateResponse = {
  version: 1;
  check_in: CheckInItem;
  daily_limit: DailyLimit;
  correlation_id: string;
  privacy_level: "sensivel";
};

export type CheckInAnswerResponse = {
  version: 1;
  status: "respondido" | "adiado";
  check_in: CheckInItem;
  energy: EnergyItem | null;
  events: unknown[];
  daily_limit: DailyLimit;
  correlation_id: string;
  privacy_level: "sensivel";
};

export type InterventionListResponse = {
  version: 1;
  interventions: InterventionItem[];
  correlation_id: string;
  privacy_level: "sensivel";
};

export type InterventionResponse = {
  version: 1;
  intervention: InterventionItem;
  energy?: EnergyItem;
  events: unknown[];
  correlation_id: string;
  privacy_level: "sensivel";
};

export type SuggestionActionResponse = {
  version: 1;
  suggestion_id: string;
  action_taken: "comecar" | "adiar" | "trocar";
  event: unknown;
  correlation_id: string;
  privacy_level: "sensivel";
};

export type SignUpInput = {
  name: string;
  email: string;
  password: string;
  pronouns?: string;
  timezone: string;
  locale: "pt-BR";
};

export type LoginInput = {
  email: string;
  password: string;
};

type RequestOptions = {
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  body?: unknown;
  correlationAction: string;
  idempotencyKey?: string;
};

type ErrorEnvelope = {
  error?: {
    code?: string;
    message?: string;
    details?: unknown[];
    correlation_id?: string;
  };
};

export class OrbApiError extends Error {
  code: string;
  status: number;
  correlationId?: string;
  details: unknown[];

  constructor({
    code,
    correlationId,
    details,
    message,
    status,
  }: {
    code: string;
    correlationId?: string;
    details?: unknown[];
    message: string;
    status: number;
  }) {
    super(message);
    this.name = "OrbApiError";
    this.code = code;
    this.status = status;
    this.correlationId = correlationId;
    this.details = details ?? [];
  }
}

export async function loadSession(signal?: AbortSignal) {
  return request<AuthSessionResponse>("/api/v1/auth/session", {
    correlationAction: "session",
    signal,
  });
}

export async function signUp(input: SignUpInput) {
  return request<AuthSessionResponse>("/api/v1/auth/sign_up", {
    method: "POST",
    correlationAction: "signup",
    body: { user: input },
  });
}

export async function login(input: LoginInput) {
  return request<AuthSessionResponse>("/api/v1/auth/login", {
    method: "POST",
    correlationAction: "login",
    body: { session: input },
  });
}

export async function logoutSession() {
  await request<null>("/api/v1/auth/session", {
    method: "DELETE",
    correlationAction: "logout",
  });
}

export async function completeOnboarding(
  answers: OnboardingAnswers,
  startedAt: string,
) {
  const now = new Date().toISOString();

  return request<OnboardingResponse>("/api/v1/onboarding/complete", {
    method: "POST",
    correlationAction: "onboarding_complete",
    idempotencyKey: createIdempotencyKey("onboarding_complete"),
    body: {
      version: 1,
      flow_variant: "resumido",
      started_at: startedAt,
      completed_at: now,
      profile_inputs: {
        ...answers,
        pronomes: null,
        tom_preferido: "acolhedor",
        intensidade_notificacao: "equilibrado",
        identificacoes_neurodivergentes: [],
      },
      skipped_sensitive_fields: true,
      first_action_requested: true,
    },
  });
}

export async function skipOnboarding() {
  return request<OnboardingResponse>("/api/v1/onboarding/skip", {
    method: "POST",
    correlationAction: "onboarding_skip",
    idempotencyKey: createIdempotencyKey("onboarding_skip"),
    body: {
      version: 1,
      occurred_at: new Date().toISOString(),
      reason: "explorar_primeiro",
      resume_reminder_opt_in: true,
    },
  });
}

export async function listTasks(signal?: AbortSignal) {
  return request<TaskListResponse>("/api/v1/tasks", {
    correlationAction: "tasks_index",
    signal,
  });
}

export async function createTask(input: TaskInput) {
  return request<{ version: 1; task: TaskItem; correlation_id: string }>(
    "/api/v1/tasks",
    {
      method: "POST",
      correlationAction: "task_create",
      idempotencyKey: createIdempotencyKey("task_create"),
      body: { task: input },
    },
  );
}

export async function updateTask(id: string, changes: Partial<TaskInput>) {
  return request<{ version: 1; task: TaskItem; correlation_id: string }>(
    `/api/v1/tasks/${id}`,
    {
      method: "PATCH",
      correlationAction: "task_update",
      idempotencyKey: createIdempotencyKey("task_update"),
      body: { changes },
    },
  );
}

export async function deleteTask(id: string) {
  await request<null>(`/api/v1/tasks/${id}`, {
    method: "DELETE",
    correlationAction: "task_delete",
    idempotencyKey: createIdempotencyKey("task_delete"),
  });
}

export async function listEvents(signal?: AbortSignal) {
  const at = encodeURIComponent(new Date().toISOString());

  return request<EventListResponse>(`/api/v1/events?at=${at}`, {
    correlationAction: "events_index",
    signal,
  });
}

export async function createEvent(input: EventInput) {
  return request<{ version: 1; event: EventItem; correlation_id: string }>(
    "/api/v1/events",
    {
      method: "POST",
      correlationAction: "event_create",
      idempotencyKey: createIdempotencyKey("event_create"),
      body: { event: input },
    },
  );
}

export async function updateEvent(id: string, changes: Partial<EventInput>) {
  return request<{ version: 1; event: EventItem; correlation_id: string }>(
    `/api/v1/events/${id}`,
    {
      method: "PATCH",
      correlationAction: "event_update",
      idempotencyKey: createIdempotencyKey("event_update"),
      body: { changes },
    },
  );
}

export async function deleteEvent(id: string) {
  await request<null>(`/api/v1/events/${id}`, {
    method: "DELETE",
    correlationAction: "event_delete",
    idempotencyKey: createIdempotencyKey("event_delete"),
  });
}

export async function loadHistory(signal?: AbortSignal) {
  return request<HistoryResponse>("/api/v1/history", {
    correlationAction: "history",
    signal,
  });
}

export async function loadCurrentEnergy(signal?: AbortSignal) {
  return request<CurrentEnergyResponse>("/api/v1/energy/current", {
    correlationAction: "energy_current",
    signal,
  });
}

export async function listCheckIns(signal?: AbortSignal) {
  return request<CheckInListResponse>("/api/v1/check_ins", {
    correlationAction: "check_ins_index",
    signal,
  });
}

export async function createCheckIn() {
  return request<CheckInCreateResponse>("/api/v1/check_ins", {
    method: "POST",
    correlationAction: "check_in_create",
    idempotencyKey: createIdempotencyKey("check_in_create"),
    body: {
      check_in: {
        tipo: "estado_energia",
        pergunta_id: "q_estado_energia_v1",
        origem: "manual",
      },
    },
  });
}

export async function respondToCheckIn(
  id: string,
  resposta: CheckInResponseValue | "adiar" | "prefiro_responder_depois",
) {
  return request<CheckInAnswerResponse>(`/api/v1/check_ins/${id}/responses`, {
    method: "POST",
    correlationAction: "check_in_response",
    idempotencyKey: createIdempotencyKey("check_in_response"),
    body: { response: { resposta } },
  });
}

export async function requestNextAction() {
  return request<NextActionResponse>("/api/v1/suggestions/next_action", {
    method: "POST",
    correlationAction: "next_action",
    idempotencyKey: createIdempotencyKey("next_action"),
  });
}

export async function recordSuggestionAction(
  suggestionId: string,
  action: "comecar" | "adiar" | "trocar",
) {
  return request<SuggestionActionResponse>(
    `/api/v1/suggestions/${suggestionId}/actions`,
    {
      method: "POST",
      correlationAction: "suggestion_action",
      idempotencyKey: createIdempotencyKey("suggestion_action"),
      body: { suggestion_action: { action } },
    },
  );
}

export async function listInterventions(signal?: AbortSignal) {
  return request<InterventionListResponse>("/api/v1/interventions", {
    correlationAction: "interventions_index",
    signal,
  });
}

export async function startIntervention(input: {
  tipo: "respiracao_guiada" | "pausa_curta";
  gatilho?: string;
  duracao_prevista_minutos: number;
}) {
  return request<InterventionResponse>("/api/v1/interventions", {
    method: "POST",
    correlationAction: "intervention_start",
    idempotencyKey: createIdempotencyKey("intervention_start"),
    body: { intervention: input },
  });
}

export async function finishIntervention(id: string, feedback?: string) {
  return request<InterventionResponse>(`/api/v1/interventions/${id}`, {
    method: "PATCH",
    correlationAction: "intervention_finish",
    idempotencyKey: createIdempotencyKey("intervention_finish"),
    body: { intervention: { feedback } },
  });
}

function createCorrelationId(action: string) {
  const randomPart =
    typeof crypto !== "undefined" && "randomUUID" in crypto
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(16).slice(2)}`;

  return `cor_web_${action}_${randomPart}`;
}

function createIdempotencyKey(action: string) {
  return `idem_web_${action}_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

async function request<T>(
  path: string,
  {
    body,
    correlationAction,
    idempotencyKey,
    method = "GET",
    signal,
  }: RequestOptions & { signal?: AbortSignal },
): Promise<T> {
  const headers = new Headers({
    "X-Orb-Source": "web",
    "X-Correlation-ID": createCorrelationId(correlationAction),
  });

  if (body !== undefined) {
    headers.set("Content-Type", "application/json");
  }

  if (idempotencyKey) {
    headers.set("Idempotency-Key", idempotencyKey);
  }

  let response: Response;

  try {
    response = await fetch(path, {
      method,
      credentials: "include",
      headers,
      signal,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw error;
    }

    throw new OrbApiError({
      code: "api_unavailable",
      message: "Sem conexao com a API. Tente novamente.",
      status: 0,
    });
  }

  if (response.status === 204) {
    return null as T;
  }

  const responseBody = (await safeJson(response)) as ErrorEnvelope | T | null;

  if (!response.ok) {
    const errorBody = isRecord(responseBody) ? responseBody.error : undefined;
    throw new OrbApiError({
      code:
        isRecord(errorBody) && typeof errorBody.code === "string"
          ? errorBody.code
          : "request_failed",
      message:
        isRecord(errorBody) && typeof errorBody.message === "string"
          ? errorBody.message
          : "Nao foi possivel concluir a requisicao.",
      details:
        isRecord(errorBody) && Array.isArray(errorBody.details)
          ? errorBody.details
          : [],
      correlationId:
        isRecord(errorBody) && typeof errorBody.correlation_id === "string"
          ? errorBody.correlation_id
          : undefined,
      status: response.status,
    });
  }

  return responseBody as T;
}

async function safeJson(response: Response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
