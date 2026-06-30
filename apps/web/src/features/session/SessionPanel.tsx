import type { FormEvent, ReactNode } from "react";
import { useEffect, useMemo, useState } from "react";
import {
  createCheckIn,
  createEvent,
  createTask,
  deleteEvent,
  deleteTask,
  finishIntervention,
  listCheckIns,
  listEvents,
  listInterventions,
  listTasks,
  loadCurrentEnergy,
  loadHistory,
  OrbApiError,
  recordSuggestionAction,
  requestNextAction,
  respondToCheckIn,
  startIntervention,
  updateEvent,
  updateTask,
  type AuthSessionResponse,
  type CheckInItem,
  type CheckInResponseValue,
  type DailyLimit,
  type EnergyItem,
  type EventInput,
  type EventItem,
  type HistoryEntry,
  type InterventionItem,
  type NextActionResponse,
  type TaskInput,
  type TaskItem,
} from "../../lib/orbApi";
import type { InitialProfile } from "../onboarding/OnboardingFlow";

type SessionPanelProps = {
  lastProfile: InitialProfile | null;
  onLogout: () => void;
  onStartOnboarding: () => void;
  session: AuthSessionResponse;
};

type LoadState =
  | { kind: "loading" }
  | { kind: "ready" }
  | { kind: "error"; message: string };

const onboardingStateLabels: Record<string, string> = {
  nao_iniciado: "nao iniciado",
  em_andamento: "em andamento",
  pulado: "pulado",
  concluido: "concluido",
  revisao_solicitada: "revisao solicitada",
};

const checkInChoices: Array<{ label: string; value: CheckInResponseValue }> = [
  { label: "Muito baixo", value: "muito_baixo" },
  { label: "Baixo", value: "baixo" },
  { label: "Neutro", value: "neutro" },
  { label: "Bom", value: "bom" },
  { label: "Alto", value: "alto" },
];

export function SessionPanel({
  lastProfile,
  onLogout,
  onStartOnboarding,
  session,
}: SessionPanelProps) {
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [events, setEvents] = useState<EventItem[]>([]);
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [checkIns, setCheckIns] = useState<CheckInItem[]>([]);
  const [dailyLimit, setDailyLimit] = useState<DailyLimit | null>(null);
  const [energy, setEnergy] = useState<EnergyItem | null>(null);
  const [nextAction, setNextAction] = useState<NextActionResponse | null>(null);
  const [interventions, setInterventions] = useState<InterventionItem[]>([]);
  const [availableWindow, setAvailableWindow] = useState<number | null>(null);
  const [loadState, setLoadState] = useState<LoadState>({ kind: "loading" });
  const [taskTitle, setTaskTitle] = useState("");
  const [taskCategory, setTaskCategory] = useState("trabalho");
  const [taskWeight, setTaskWeight] = useState<TaskInput["peso"]>("medio");
  const [taskMinutes, setTaskMinutes] = useState(45);
  const [taskContext, setTaskContext] = useState("");
  const [eventTitle, setEventTitle] = useState("");
  const [eventStart, setEventStart] = useState(() => defaultLocalDateTime(60));
  const [eventEnd, setEventEnd] = useState(() => defaultLocalDateTime(120));
  const [eventCategory, setEventCategory] = useState("trabalho");
  const [editingTask, setEditingTask] = useState<{ id: string; title: string } | null>(
    null,
  );
  const [editingEvent, setEditingEvent] =
    useState<{ id: string; title: string } | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [interventionFeedback, setInterventionFeedback] = useState("");

  const onboarding = session.user.onboarding;
  const onboardingLabel =
    onboardingStateLabels[onboarding?.state ?? "nao_iniciado"] ??
    "nao iniciado";
  const shouldShowOnboardingAction =
    onboarding?.state !== "concluido" &&
    onboarding?.state !== "revisao_solicitada";
  const nextTask = useMemo(
    () => tasks.find((task) => task.status !== "concluido"),
    [tasks],
  );
  const activeCheckIn = useMemo(
    () => checkIns.find((checkIn) => !checkIn.resposta),
    [checkIns],
  );
  const activeIntervention = useMemo(
    () => interventions.find((intervention) => !intervention.fim),
    [interventions],
  );

  useEffect(() => {
    const controller = new AbortController();
    void refresh(controller.signal);

    return () => controller.abort();
  }, []);

  async function refresh(signal?: AbortSignal) {
    setLoadState({ kind: "loading" });

    try {
      const [taskList, eventList, historyList, checkInList, interventionList, energyResult] =
        await Promise.all([
          listTasks(signal),
          listEvents(signal),
          loadHistory(signal),
          listCheckIns(signal),
          listInterventions(signal),
          loadEnergyOptional(signal),
        ]);
      setTasks(taskList.tasks);
      setEvents(eventList.events);
      setAvailableWindow(eventList.available_window_minutes ?? null);
      setHistory(historyList.history);
      setCheckIns(checkInList.check_ins);
      setDailyLimit(checkInList.daily_limit);
      setInterventions(interventionList.interventions);
      setEnergy(energyResult?.energy ?? null);
      setLoadState({ kind: "ready" });
    } catch (error) {
      if (signal?.aborted) {
        return;
      }

      setLoadState({
        kind: "error",
        message:
          error instanceof Error
            ? error.message
            : "Sem conexao com a API. Tente novamente.",
      });
    }
  }

  async function runAction(action: () => Promise<void>) {
    setActionMessage(null);

    try {
      await action();
    } catch (error) {
      setActionMessage(
        error instanceof Error
          ? error.message
          : "Nao foi possivel concluir esta acao.",
      );
    }
  }

  async function loadEnergyOptional(signal?: AbortSignal) {
    try {
      return await loadCurrentEnergy(signal);
    } catch (error) {
      if (error instanceof OrbApiError && error.status === 404) {
        return null;
      }

      throw error;
    }
  }

  async function handleCreateTask(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setActionMessage(null);

    try {
      const response = await createTask({
        titulo: taskTitle.trim(),
        categoria: taskCategory,
        duracao_estimada_minutos: taskMinutes,
        peso: taskWeight,
        contexto: taskContext.trim() || undefined,
      });
      setTasks((current) => [response.task, ...current]);
      setTaskTitle("");
      setTaskContext("");
      setActionMessage("Tarefa criada e confirmada pelo servidor.");
      void refresh();
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : "Nao foi possivel criar a tarefa.");
    }
  }

  async function handleCreateEvent(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setActionMessage(null);

    try {
      const response = await createEvent({
        titulo: eventTitle.trim(),
        inicio: toIsoDateTime(eventStart),
        fim: toIsoDateTime(eventEnd),
        timezone: session.user.timezone,
        categoria: eventCategory,
        peso: "leve",
      });
      setEvents((current) =>
        [...current, response.event].sort((a, b) => a.inicio.localeCompare(b.inicio)),
      );
      setEventTitle("");
      setActionMessage("Evento criado e janela recalculada pelo servidor.");
      void refresh();
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : "Nao foi possivel criar o evento.");
    }
  }

  async function handleCreateCheckIn() {
    const response = await createCheckIn();
    setCheckIns((current) => [response.check_in, ...current]);
    setDailyLimit(response.daily_limit);
    setActionMessage("Check-in criado pelo servidor.");
  }

  async function handleCheckInResponse(
    resposta: CheckInResponseValue | "prefiro_responder_depois",
  ) {
    if (!activeCheckIn) {
      return;
    }

    const response = await respondToCheckIn(activeCheckIn.id, resposta);
    setCheckIns((current) =>
      upsertById(current, response.check_in).sort((a, b) =>
        b.created_at.localeCompare(a.created_at),
      ),
    );
    setDailyLimit(response.daily_limit);

    if (response.energy) {
      setEnergy(response.energy);
      setActionMessage("Energia recalibrada pelo servidor.");
      return;
    }

    setActionMessage("Tudo bem responder depois. O Orb vai esperar sem insistir.");
  }

  async function handleRequestNextAction() {
    const response = await requestNextAction();
    setNextAction(response);
    setActionMessage("Proxima acao calculada pelo motor deterministico.");
  }

  async function handleSuggestionAction(action: "comecar" | "adiar" | "trocar") {
    if (!nextAction) {
      return;
    }

    await recordSuggestionAction(nextAction.suggestion_id, action);

    const resource = nextAction.action.resource;
    if (resource.type === "tarefa" && resource.id !== "nova") {
      if (action === "comecar") {
        const response = await updateTask(resource.id, { status: "em_progresso" });
        setTasks((current) =>
          current.map((item) => (item.id === resource.id ? response.task : item)),
        );
      }

      if (action === "adiar") {
        const response = await updateTask(resource.id, { status: "adiado" });
        setTasks((current) =>
          current.map((item) => (item.id === resource.id ? response.task : item)),
        );
      }
    }

    if (action === "trocar") {
      const exchanged = await requestNextAction();
      setNextAction(exchanged);
      setActionMessage("Sugestao trocada sem usar LLM.");
      return;
    }

    setActionMessage(
      action === "comecar"
        ? "Proxima acao aceita e registrada."
        : "Proxima acao adiada com suavidade.",
    );
    void refresh();
  }

  async function handleStartIntervention(trigger = "sobrecarga") {
    const response = await startIntervention({
      tipo: "respiracao_guiada",
      gatilho: trigger,
      duracao_prevista_minutos: 3,
    });
    setInterventions((current) => [response.intervention, ...current]);
    setActionMessage("Intervencao iniciada com duracao previsivel.");
  }

  async function handleFinishIntervention() {
    if (!activeIntervention) {
      return;
    }

    const response = await finishIntervention(
      activeIntervention.id,
      interventionFeedback.trim() || undefined,
    );
    setInterventions((current) =>
      upsertById(current, response.intervention).sort((a, b) =>
        b.inicio.localeCompare(a.inicio),
      ),
    );
    if (response.energy) {
      setEnergy(response.energy);
    }
    setInterventionFeedback("");
    setActionMessage("Intervencao finalizada e energia recalibrada.");
  }

  async function changeTaskStatus(task: TaskItem, status: TaskItem["status"]) {
    const response = await updateTask(task.id, { status });
    setTasks((current) =>
      current.map((item) => (item.id === task.id ? response.task : item)),
    );
    setActionMessage(status === "concluido" ? "Tarefa concluida." : "Tarefa adiada.");
    void refresh();
  }

  async function saveTaskTitle(task: TaskItem) {
    if (!editingTask || editingTask.title.trim() === "") {
      return;
    }

    const response = await updateTask(task.id, { titulo: editingTask.title.trim() });
    setTasks((current) =>
      current.map((item) => (item.id === task.id ? response.task : item)),
    );
    setEditingTask(null);
    setActionMessage("Tarefa atualizada.");
    void refresh();
  }

  async function removeTask(task: TaskItem) {
    await deleteTask(task.id);
    setTasks((current) => current.filter((item) => item.id !== task.id));
    setActionMessage("Tarefa excluida das views ativas.");
    void refresh();
  }

  async function saveEventTitle(event: EventItem) {
    if (!editingEvent || editingEvent.title.trim() === "") {
      return;
    }

    const response = await updateEvent(event.id, { titulo: editingEvent.title.trim() });
    setEvents((current) =>
      current.map((item) => (item.id === event.id ? response.event : item)),
    );
    setEditingEvent(null);
    setActionMessage("Evento atualizado.");
    void refresh();
  }

  async function removeEvent(event: EventItem) {
    await deleteEvent(event.id);
    setEvents((current) => current.filter((item) => item.id !== event.id));
    setActionMessage("Evento removido das views ativas.");
    void refresh();
  }

  return (
    <main className="app-shell session-shell" aria-labelledby="session-title">
      <section className="today-layout" data-route="/hoje">
        <header className="today-header">
          <div>
            <p className="eyebrow">Hoje</p>
            <h1 id="session-title">O que eu faco agora?</h1>
            <p className="lede">
              Conta autenticada. Tarefas, eventos e historico curto sao
              confirmados pela API.
            </p>
          </div>
          <nav className="actions compact-actions" aria-label="Conta e onboarding">
            {shouldShowOnboardingAction && (
              <button
                className="secondary-button"
                type="button"
                onClick={onStartOnboarding}
              >
                {onboarding?.state === "em_andamento"
                  ? "Retomar onboarding"
                  : "Completar onboarding"}
              </button>
            )}
            <button className="secondary-button" type="button" onClick={() => void refresh()}>
              Tentar novamente
            </button>
            <button className="link-button" type="button" onClick={onLogout}>
              Sair
            </button>
          </nav>
        </header>

        {loadState.kind === "error" && (
          <p className="error-banner" role="alert">
            {loadState.message}
          </p>
        )}
        {loadState.kind === "loading" && (
          <p className="inline-note" role="status">
            Carregando tarefas, eventos e historico...
          </p>
        )}
        {actionMessage && (
          <p className="inline-note" role="status">
            {actionMessage}
          </p>
        )}

        <section className="today-grid">
          <article className="session-card focus-panel" aria-labelledby="focus-title">
            <p className="eyebrow">Orb</p>
            <h2 id="focus-title">{formatEnergyState(energy?.estado_qualitativo)}</h2>
            <div
              aria-label={`Orb com energia ${energy?.valor ?? 0}`}
              className={`orb-meter orb-meter-${energy?.estado_qualitativo ?? "vazio"}`}
              role="img"
            >
              <span style={{ width: `${energy?.valor ?? 32}%` }} />
            </div>
            <p className="lede">
              {energy
                ? `Fonte ${energy.fonte_calibracao}; confianca ${energy.confianca}.`
                : "Responda um check-in para calibrar a energia oficial."}
            </p>
            <dl className="session-facts compact-facts">
              <div>
                <dt>Usuario</dt>
                <dd>{session.user.nome}</dd>
              </div>
              <div>
                <dt>Email</dt>
                <dd>{session.user.email}</dd>
              </div>
              <div>
                <dt>Plano</dt>
                <dd>{session.user.plano_atual}</dd>
              </div>
              <div>
                <dt>Onboarding</dt>
                <dd>{onboardingLabel}</dd>
              </div>
            </dl>
          </article>

          <article className="session-card" aria-labelledby="checkin-title">
            <p className="eyebrow">Check-in</p>
            <h3 id="checkin-title">Energia agora</h3>
            <p className="lede">
              {dailyLimit
                ? `${dailyLimit.used}/${dailyLimit.limit} check-ins usados no plano ${dailyLimit.plan}.`
                : "Limite sera confirmado pelo servidor."}
            </p>
            {activeCheckIn ? (
              <div className="stack-form">
                <p className="inline-note">
                  Check-in aberto para {activeCheckIn.horario_previsto}.
                </p>
                <div className="response-grid" aria-label="Responder check-in">
                  {checkInChoices.map((choice) => (
                    <button
                      className="secondary-button small-button"
                      key={choice.value}
                      type="button"
                      onClick={() => void runAction(() => handleCheckInResponse(choice.value))}
                    >
                      {choice.label}
                    </button>
                  ))}
                  <button
                    className="link-button"
                    type="button"
                    onClick={() =>
                      void runAction(() =>
                        handleCheckInResponse("prefiro_responder_depois"),
                      )
                    }
                  >
                    Responder depois
                  </button>
                </div>
              </div>
            ) : (
              <button
                className="primary-button"
                disabled={dailyLimit?.remaining === 0}
                type="button"
                onClick={() => void runAction(handleCreateCheckIn)}
              >
                Criar check-in
              </button>
            )}
          </article>

          <article className="session-card" aria-labelledby="next-action-title">
            <p className="eyebrow">Proxima acao</p>
            <h3 id="next-action-title">
              {nextAction
                ? formatActionTitle(nextAction, tasks)
                : nextTask?.titulo ?? "Aguardando motor"}
            </h3>
            <p className="lede">
              {nextAction
                ? nextAction.reason
                : availableWindow == null
                  ? "Sem proximo evento ativo no horizonte carregado."
                  : `${availableWindow} minutos ate o proximo evento.`}
            </p>
            {nextAction && (
              <p className="inline-note">
                Motor deterministico · sem LLM · energia{" "}
                {nextAction.explanation_inputs.energia_estado}
              </p>
            )}
            <div className="item-actions">
              <button
                className="primary-button"
                type="button"
                onClick={() => void runAction(handleRequestNextAction)}
              >
                Gerar proxima acao
              </button>
              {nextAction?.action.type === "regular" ? (
                <button
                  className="secondary-button"
                  type="button"
                  onClick={() => void runAction(() => handleStartIntervention("sobrecarga"))}
                >
                  Iniciar respiracao
                </button>
              ) : (
                nextAction && (
                  <>
                    <button className="secondary-button small-button" type="button" onClick={() => void runAction(() => handleSuggestionAction("comecar"))}>
                      Comecar
                    </button>
                    <button className="secondary-button small-button" type="button" onClick={() => void runAction(() => handleSuggestionAction("adiar"))}>
                      Adiar
                    </button>
                    <button className="link-button" type="button" onClick={() => void runAction(() => handleSuggestionAction("trocar"))}>
                      Trocar
                    </button>
                  </>
                )
              )}
            </div>
          </article>

          <article className="session-card" aria-labelledby="regulation-title">
            <p className="eyebrow">Regulacao</p>
            <h3 id="regulation-title">
              {activeIntervention ? "Pausa em andamento" : "Pausa ou respiracao"}
            </h3>
            <p className="lede">
              {activeIntervention
                ? `${activeIntervention.duracao_prevista_minutos} minutos previstos desde ${formatDate(activeIntervention.inicio)}.`
                : "Sobrecarga e recuperacao protegem uma pausa antes da tarefa."}
            </p>
            {activeIntervention ? (
              <div className="stack-form">
                <label className="field">
                  <span>Feedback opcional</span>
                  <input
                    value={interventionFeedback}
                    onChange={(event) => setInterventionFeedback(event.target.value)}
                  />
                </label>
                <button className="primary-button alt" type="button" onClick={() => void runAction(handleFinishIntervention)}>
                  Finalizar intervencao
                </button>
              </div>
            ) : (
              <button className="secondary-button" type="button" onClick={() => void runAction(() => handleStartIntervention("manual"))}>
                Iniciar pausa
              </button>
            )}
          </article>

          <article className="session-card" aria-labelledby="task-form-title">
            <h3 id="task-form-title">Nova tarefa</h3>
            <form className="stack-form" onSubmit={handleCreateTask}>
              <label className="field">
                <span>Titulo da tarefa</span>
                <input
                  required
                  value={taskTitle}
                  onChange={(event) => setTaskTitle(event.target.value)}
                />
              </label>
              <div className="form-row">
                <label className="field">
                  <span>Categoria</span>
                  <input
                    value={taskCategory}
                    onChange={(event) => setTaskCategory(event.target.value)}
                  />
                </label>
                <label className="field">
                  <span>Peso</span>
                  <select
                    value={taskWeight}
                    onChange={(event) =>
                      setTaskWeight(event.target.value as TaskInput["peso"])
                    }
                  >
                    <option value="leve">Leve</option>
                    <option value="medio">Medio</option>
                    <option value="pesado">Pesado</option>
                  </select>
                </label>
                <label className="field">
                  <span>Minutos</span>
                  <input
                    min={1}
                    type="number"
                    value={taskMinutes}
                    onChange={(event) => setTaskMinutes(Number(event.target.value))}
                  />
                </label>
              </div>
              <label className="field">
                <span>Contexto opcional</span>
                <textarea
                  value={taskContext}
                  onChange={(event) => setTaskContext(event.target.value)}
                />
              </label>
              <button className="primary-button" type="submit">
                Criar tarefa
              </button>
            </form>
          </article>

          <article className="session-card" aria-labelledby="event-form-title">
            <h3 id="event-form-title">Novo evento</h3>
            <form className="stack-form" onSubmit={handleCreateEvent}>
              <label className="field">
                <span>Titulo do evento</span>
                <input
                  required
                  value={eventTitle}
                  onChange={(event) => setEventTitle(event.target.value)}
                />
              </label>
              <div className="form-row">
                <label className="field">
                  <span>Inicio</span>
                  <input
                    required
                    type="datetime-local"
                    value={eventStart}
                    onChange={(event) => setEventStart(event.target.value)}
                  />
                </label>
                <label className="field">
                  <span>Fim</span>
                  <input
                    required
                    type="datetime-local"
                    value={eventEnd}
                    onChange={(event) => setEventEnd(event.target.value)}
                  />
                </label>
              </div>
              <label className="field">
                <span>Categoria</span>
                <input
                  value={eventCategory}
                  onChange={(event) => setEventCategory(event.target.value)}
                />
              </label>
              <button className="primary-button alt" type="submit">
                Criar evento
              </button>
            </form>
          </article>
        </section>

        <section className="work-grid" aria-label="Itens ativos e historico">
          <article className="session-card" aria-labelledby="tasks-title">
            <h3 id="tasks-title">Tarefas ativas</h3>
            <ItemList emptyText="Nenhuma tarefa ativa ainda.">
              {tasks.map((task) => (
                <li className="work-item" key={task.id}>
                  {editingTask?.id === task.id ? (
                    <label className="field compact-field">
                      <span>Editar titulo</span>
                      <input
                        value={editingTask.title}
                        onChange={(event) =>
                          setEditingTask({ id: task.id, title: event.target.value })
                        }
                      />
                    </label>
                  ) : (
                    <div>
                      <strong>{task.titulo}</strong>
                      <span>{task.status} · {task.peso ?? "peso aberto"}</span>
                    </div>
                  )}
                  <div className="item-actions">
                    {editingTask?.id === task.id ? (
                      <button className="secondary-button small-button" type="button" onClick={() => void runAction(() => saveTaskTitle(task))}>
                        Salvar
                      </button>
                    ) : (
                      <button className="secondary-button small-button" type="button" onClick={() => setEditingTask({ id: task.id, title: task.titulo })}>
                        Editar
                      </button>
                    )}
                    <button className="secondary-button small-button" type="button" onClick={() => void runAction(() => changeTaskStatus(task, "concluido"))}>
                      Concluir
                    </button>
                    <button className="secondary-button small-button" type="button" onClick={() => void runAction(() => changeTaskStatus(task, "adiado"))}>
                      Adiar
                    </button>
                    <button className="link-button" type="button" onClick={() => void runAction(() => removeTask(task))}>
                      Excluir
                    </button>
                  </div>
                </li>
              ))}
            </ItemList>
          </article>

          <article className="session-card" aria-labelledby="events-title">
            <h3 id="events-title">Eventos</h3>
            <ItemList emptyText="Nenhum evento ativo ainda.">
              {events.map((event) => (
                <li className="work-item" key={event.id}>
                  {editingEvent?.id === event.id ? (
                    <label className="field compact-field">
                      <span>Editar titulo</span>
                      <input
                        value={editingEvent.title}
                        onChange={(change) =>
                          setEditingEvent({ id: event.id, title: change.target.value })
                        }
                      />
                    </label>
                  ) : (
                    <div>
                      <strong>{event.titulo}</strong>
                      <span>{formatDate(event.inicio)} · {event.timezone}</span>
                    </div>
                  )}
                  <div className="item-actions">
                    {editingEvent?.id === event.id ? (
                      <button className="secondary-button small-button" type="button" onClick={() => void runAction(() => saveEventTitle(event))}>
                        Salvar
                      </button>
                    ) : (
                      <button className="secondary-button small-button" type="button" onClick={() => setEditingEvent({ id: event.id, title: event.titulo })}>
                        Editar
                      </button>
                    )}
                    <button className="link-button" type="button" onClick={() => void runAction(() => removeEvent(event))}>
                      Excluir
                    </button>
                  </div>
                </li>
              ))}
            </ItemList>
          </article>

          <article className="session-card" aria-labelledby="history-title">
            <h3 id="history-title">Historico curto</h3>
            <ItemList emptyText="O historico aparece apos a primeira acao.">
              {history.slice(0, 8).map((entry) => (
                <li className="history-item" key={`${entry.event_type}-${entry.resource.id}-${entry.occurred_at}`}>
                  <strong>{formatEventType(entry.event_type)}</strong>
                  <span>{formatDate(entry.occurred_at)}</span>
                  <small>{formatSummary(entry.summary)}</small>
                </li>
              ))}
            </ItemList>
          </article>
        </section>

        {lastProfile && (
          <aside className="session-card profile-strip" aria-labelledby="last-profile-title">
            <h3 id="last-profile-title">Perfil Energetico inicial</h3>
            <p className="profile-big">{lastProfile.arquetipo}</p>
            <p>
              Confianca {lastProfile.confianca_inicial}; rotina de{" "}
              {lastProfile.horario_primeiro_check_in} a{" "}
              {lastProfile.horario_ultimo_check_in}.
            </p>
          </aside>
        )}
      </section>
    </main>
  );
}

function ItemList({
  children,
  emptyText,
}: {
  children: ReactNode;
  emptyText: string;
}) {
  const hasItems = Array.isArray(children) ? children.length > 0 : Boolean(children);

  if (!hasItems) {
    return <p className="empty-state">{emptyText}</p>;
  }

  return <ul className="work-list">{children}</ul>;
}

function defaultLocalDateTime(minutesFromNow: number) {
  const date = new Date(Date.now() + minutesFromNow * 60_000);
  date.setSeconds(0, 0);
  return date.toISOString().slice(0, 16);
}

function toIsoDateTime(value: string) {
  return new Date(value).toISOString();
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

function formatEventType(value: string) {
  return value.replaceAll("_", " ");
}

function formatSummary(summary: Record<string, unknown>) {
  if (summary.tombstone) {
    return "tombstone minimizado";
  }

  const title = typeof summary.titulo === "string" ? summary.titulo : null;
  const status = typeof summary.status === "string" ? summary.status : null;
  const state =
    typeof summary.estado_qualitativo === "string"
      ? `energia ${summary.estado_qualitativo}`
      : null;

  return [title, status, state].filter(Boolean).join(" · ") || "evento registrado";
}

function upsertById<T extends { id: string }>(items: T[], nextItem: T) {
  const exists = items.some((item) => item.id === nextItem.id);
  if (!exists) {
    return [nextItem, ...items];
  }

  return items.map((item) => (item.id === nextItem.id ? nextItem : item));
}

function formatEnergyState(state?: EnergyItem["estado_qualitativo"]) {
  const labels: Record<EnergyItem["estado_qualitativo"], string> = {
    alta: "Energia alta",
    media: "Energia media",
    baixa: "Energia baixa",
    em_recuperacao: "Em recuperacao",
    em_sobrecarga: "Em sobrecarga",
  };

  return state ? labels[state] : "Aguardando check-in";
}

function formatActionTitle(nextAction: NextActionResponse, tasks: TaskItem[]) {
  if (nextAction.action.type === "regular") {
    return "Regular antes de seguir";
  }

  if (nextAction.action.resource.type === "tarefa") {
    const task = tasks.find((item) => item.id === nextAction.action.resource.id);
    return task?.titulo ?? `Tarefa ${nextAction.action.resource.id}`;
  }

  return "Proxima acao pronta";
}
