import type { CSSProperties, FormEvent } from "react";
import { useState } from "react";
import {
  completeOnboarding,
  skipOnboarding,
  type AuthSessionResponse,
  type Objective,
  type OnboardingAnswers,
  type Sensitivity,
  type SessionUser,
} from "../../lib/orbApi";

type CompletionMode = "complete" | "skip";
type CreationMode = "task" | "event";

export type InitialProfile = OnboardingAnswers & {
  version: 1;
  source: "web";
  flow_variant: "resumido";
  state: "onboarding_concluido" | "onboarding_pulado";
  arquetipo: string;
  confianca_inicial: "baixa" | "media";
  data_onboarding: string;
  tom_preferido: "acolhedor";
  intensidade_notificacao: "equilibrado";
};

export type OnboardingStateChange = {
  state: "concluido" | "pulado";
  profile: InitialProfile;
};

type SyncState =
  | { status: "idle" }
  | { status: "pending"; message: string }
  | { status: "confirmed"; message: string }
  | { status: "fallback"; message: string };

type Choice<T extends string> = {
  value: T;
  label: string;
  hint: string;
};

const steps = [
  "Boas-vindas",
  "Identificacao",
  "Objetivo",
  "Rotina e janelas",
  "Gatilhos",
  "Resultado",
] as const;

const objectiveChoices: Choice<Objective>[] = [
  {
    value: "trabalho",
    label: "Trabalho",
    hint: "Entregas, reunioes e prioridades profissionais.",
  },
  {
    value: "estudo",
    label: "Estudo",
    hint: "Aulas, leituras, revisoes e provas.",
  },
  {
    value: "casa_e_familia",
    label: "Casa e familia",
    hint: "Rotina domestica, cuidado e combinados.",
  },
  {
    value: "autocuidado",
    label: "Autocuidado",
    hint: "Energia, descanso e recuperacao no dia a dia.",
  },
  {
    value: "transicao_de_carreira",
    label: "Transicao de carreira",
    hint: "Mudancas, estudo novo e proximos passos.",
  },
  {
    value: "rotina_geral",
    label: "Rotina geral",
    hint: "Um desenho inicial leve para organizar tudo.",
  },
];

const peakWindowChoices = [
  { value: "manha_cedo", label: "Manha cedo" },
  { value: "fim_da_manha", label: "Fim da manha" },
  { value: "tarde", label: "Tarde" },
  { value: "noite", label: "Noite" },
  { value: "varia_muito", label: "Varia muito" },
  { value: "ainda_nao_sei", label: "Ainda nao sei" },
];

const lowWindowChoices = [
  { value: "ao_acordar", label: "Ao acordar" },
  { value: "depois_do_almoco", label: "Depois do almoco" },
  { value: "fim_da_tarde", label: "Fim da tarde" },
  { value: "noite", label: "Noite" },
  { value: "depois_de_reunioes", label: "Depois de reunioes" },
  { value: "ainda_nao_sei", label: "Ainda nao sei" },
];

const triggerChoices = [
  { value: "barulho", label: "Barulho" },
  { value: "luz_forte", label: "Luz forte" },
  { value: "reunioes_longas", label: "Reunioes longas" },
  { value: "decisoes_pequenas", label: "Muitas decisoes pequenas" },
  { value: "tarefas_sem_comeco", label: "Tarefas sem comeco claro" },
  { value: "nenhum", label: "Nenhum que eu saiba" },
];

const sensitivityChoices: Choice<Sensitivity>[] = [
  {
    value: "baixa",
    label: "Pouco",
    hint: "Consigo seguir mesmo com algum ruido.",
  },
  {
    value: "media",
    label: "Medio",
    hint: "Depende do dia. Vamos com equilibrio.",
  },
  {
    value: "alta",
    label: "Bastante",
    hint: "Ambiente pesa rapido; prefiro mais cuidado.",
  },
];

function createInitialAnswers(user?: SessionUser): OnboardingAnswers {
  return {
    nome: user?.nome ?? "",
    timezone:
      user?.timezone ||
      Intl.DateTimeFormat().resolvedOptions().timeZone ||
      "America/Sao_Paulo",
    idioma: "pt-BR",
    objetivo_principal: "rotina_geral",
    horario_primeiro_check_in: "08:00",
    horario_ultimo_check_in: "18:00",
    janelas_pico: ["ainda_nao_sei"],
    janelas_baixa_energia: ["ainda_nao_sei"],
    gatilhos: ["nenhum"],
    sensibilidade: "media",
  };
}

function createSkipAnswers(current: OnboardingAnswers): OnboardingAnswers {
  return {
    ...current,
    nome: current.nome.trim() || "Voce",
    objetivo_principal: "rotina_geral",
    horario_primeiro_check_in: "08:00",
    horario_ultimo_check_in: "18:00",
    janelas_pico: [],
    janelas_baixa_energia: [],
    gatilhos: [],
    sensibilidade: "media",
  };
}

function buildLocalProfile(
  answers: OnboardingAnswers,
  mode: CompletionMode,
): InitialProfile {
  return {
    ...answers,
    version: 1,
    source: "web",
    flow_variant: "resumido",
    state: mode === "skip" ? "onboarding_pulado" : "onboarding_concluido",
    arquetipo: buildArchetype(answers),
    confianca_inicial: mode === "skip" ? "baixa" : "media",
    data_onboarding: new Date().toISOString(),
    tom_preferido: "acolhedor",
    intensidade_notificacao: "equilibrado",
  };
}

function buildArchetype(answers: OnboardingAnswers) {
  const windows = answers.janelas_pico;
  const knownWindows = windows.filter(
    (window) => window !== "ainda_nao_sei" && window !== "varia_muito",
  );

  const firstTerm =
    windows.length === 0 || windows.includes("ainda_nao_sei")
      ? "Explorador"
      : windows.includes("varia_muito") || knownWindows.length > 1
        ? "Pendulo"
        : knownWindows.includes("manha_cedo") ||
            knownWindows.includes("fim_da_manha")
          ? "Cotovia"
          : knownWindows.includes("tarde")
            ? "Pulso"
            : knownWindows.includes("noite")
              ? "Coruja"
              : "Explorador";

  const secondTermByObjective: Record<Objective, string> = {
    trabalho: "Estrategica",
    estudo: "Focada",
    casa_e_familia: "Cuidadora",
    autocuidado: firstTerm === "Explorador" ? "Restaurador" : "Restauradora",
    transicao_de_carreira: "Em Movimento",
    rotina_geral: "Versatil",
  };

  return `${firstTerm} ${secondTermByObjective[answers.objetivo_principal]}`;
}

function mergeServerProfile(
  responseBody: unknown,
  fallbackProfile: InitialProfile,
): InitialProfile {
  if (!isRecord(responseBody)) {
    return fallbackProfile;
  }

  const candidate = isRecord(responseBody.perfil_energetico)
    ? responseBody.perfil_energetico
    : isRecord(responseBody.perfil_energetico_inicial)
      ? responseBody.perfil_energetico_inicial
      : isRecord(responseBody.profile)
        ? responseBody.profile
        : responseBody;

  return {
    ...fallbackProfile,
    arquetipo:
      typeof candidate.arquetipo === "string"
        ? candidate.arquetipo
        : fallbackProfile.arquetipo,
    confianca_inicial:
      candidate.confianca === "baixa" || candidate.confianca_inicial === "baixa"
        ? "baixa"
        : fallbackProfile.confianca_inicial,
    data_onboarding:
      typeof candidate.data_onboarding === "string"
        ? candidate.data_onboarding
        : fallbackProfile.data_onboarding,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function toggleList(
  list: string[],
  value: string,
  exclusiveValues: string[] = [],
) {
  if (exclusiveValues.includes(value)) {
    return list.includes(value) ? [] : [value];
  }

  const withoutExclusive = list.filter((item) => !exclusiveValues.includes(item));
  return withoutExclusive.includes(value)
    ? withoutExclusive.filter((item) => item !== value)
    : [...withoutExclusive, value];
}

function curveForProfile(profile: InitialProfile) {
  const periods = [
    { key: "manha_cedo", label: "Manha", height: 45 },
    { key: "fim_da_manha", label: "Meio", height: 52 },
    { key: "tarde", label: "Tarde", height: 46 },
    { key: "noite", label: "Noite", height: 42 },
  ];

  if (profile.janelas_pico.length === 0) {
    return periods.map((period) => ({ ...period, height: 50 }));
  }

  return periods.map((period) => ({
    ...period,
    height: profile.janelas_pico.includes(period.key) ? 82 : period.height,
  }));
}

type OnboardingFlowProps = {
  session: AuthSessionResponse;
  onBackToSession: () => void;
  onFinished: (change: OnboardingStateChange) => void;
  onLogout: () => void;
};

export function OnboardingFlow({
  onBackToSession,
  onFinished,
  onLogout,
  session,
}: OnboardingFlowProps) {
  const [startedAt] = useState(() => new Date().toISOString());
  const [answers, setAnswers] = useState(() =>
    createInitialAnswers(session.user),
  );
  const [currentStep, setCurrentStep] = useState(0);
  const [profile, setProfile] = useState<InitialProfile | null>(null);
  const [syncState, setSyncState] = useState<SyncState>({ status: "idle" });
  const [completionMode, setCompletionMode] =
    useState<CompletionMode>("complete");
  const [creationMode, setCreationMode] = useState<CreationMode | null>(null);
  const [draftTitle, setDraftTitle] = useState("");
  const [draftSaved, setDraftSaved] = useState(false);

  const progressLabel = `${currentStep + 1} de ${steps.length}`;
  const isResultStep = currentStep === steps.length - 1;

  async function submitOnboarding(mode: CompletionMode) {
    const answersForMode =
      mode === "skip" ? createSkipAnswers(answers) : { ...answers };
    const fallbackProfile = buildLocalProfile(answersForMode, mode);
    setCompletionMode(mode);
    setSyncState({
      status: "pending",
      message: "Confirmando com o servidor...",
    });

    try {
      const body: unknown =
        mode === "skip"
          ? await skipOnboarding()
          : await completeOnboarding(answersForMode, startedAt);
      const confirmedProfile = mergeServerProfile(body, fallbackProfile);
      setProfile(confirmedProfile);
      onFinished({
        state: mode === "skip" ? "pulado" : "concluido",
        profile: confirmedProfile,
      });
      setSyncState({
        status: "confirmed",
        message: "Perfil confirmado pelo servidor.",
      });
    } catch {
      setProfile(fallbackProfile);
      setSyncState({
        status: "fallback",
        message:
          "Sem conexao com o servidor. Esta previa local ajuda na demo, mas a versao oficial precisa ser confirmada pela API.",
      });
    }

    setCurrentStep(steps.length - 1);
  }

  function handleNext(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (currentStep === steps.length - 2) {
      void submitOnboarding("complete");
      return;
    }

    setCurrentStep((step) => Math.min(step + 1, steps.length - 1));
  }

  function handleBack() {
    setCreationMode(null);
    setDraftSaved(false);

    if (isResultStep) {
      setProfile(null);
      setSyncState({ status: "idle" });
      setCurrentStep(steps.length - 2);
      return;
    }

    setCurrentStep((step) => Math.max(step - 1, 0));
  }

  function retryConfirmation() {
    void submitOnboarding(completionMode);
  }

  function updateAnswer<Key extends keyof OnboardingAnswers>(
    key: Key,
    value: OnboardingAnswers[Key],
  ) {
    setAnswers((current) => ({ ...current, [key]: value }));
  }

  function saveDraft(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setDraftSaved(true);
  }

  return (
    <main className="app-shell app-shell-responsive" aria-labelledby="page-title">
      <section className="onboarding-frame" aria-label="Onboarding resumido">
        <header className="topbar">
          <div>
            <p className="eyebrow">Onboarding resumido</p>
            <h1 id="page-title">Orb</h1>
          </div>
          <div className="session-actions" aria-label="Sessao atual">
            <p className="online-note">
              {session.user.email} · online-only
            </p>
            <button
              className="link-button"
              type="button"
              onClick={onBackToSession}
            >
              Sessao
            </button>
            <button className="link-button" type="button" onClick={onLogout}>
              Sair
            </button>
          </div>
        </header>

        <div className="progress-wrap" aria-label={`Progresso ${progressLabel}`}>
          <span className="progress-text">{progressLabel}</span>
          <div className="progress-track" aria-hidden="true">
            <span
              className="progress-fill"
              style={
                {
                  "--progress": `${((currentStep + 1) / steps.length) * 100}%`,
                } as CSSProperties
              }
            />
          </div>
        </div>

        {syncState.status !== "idle" && (
          <div
            className={`sync-banner sync-banner-${syncState.status}`}
            role={syncState.status === "fallback" ? "alert" : "status"}
          >
            <span>{syncState.message}</span>
            {syncState.status === "fallback" && (
              <button
                className="link-button"
                type="button"
                onClick={retryConfirmation}
              >
                Tentar novamente
              </button>
            )}
          </div>
        )}

        {isResultStep && profile ? (
          <ResultStep
            creationMode={creationMode}
            draftSaved={draftSaved}
            draftTitle={draftTitle}
            onBack={handleBack}
            onCreate={setCreationMode}
            onDraftTitleChange={setDraftTitle}
            onSaveDraft={saveDraft}
            profile={profile}
          />
        ) : (
          <form className="step-card" onSubmit={handleNext}>
            <StepContent
              answers={answers}
              currentStep={currentStep}
              updateAnswer={updateAnswer}
            />

            <nav className="actions" aria-label="Acoes do onboarding">
              <button
                className="secondary-button"
                disabled={currentStep === 0}
                type="button"
                onClick={handleBack}
              >
                Voltar
              </button>
              <button
                className="ghost-button"
                type="button"
                onClick={() => void submitOnboarding("skip")}
              >
                Explorar primeiro
              </button>
              <button className="primary-button" type="submit">
                {currentStep === 0
                  ? "Comecar"
                  : currentStep === steps.length - 2
                    ? "Ver resultado"
                    : "Continuar"}
              </button>
            </nav>
          </form>
        )}
      </section>
    </main>
  );
}

type StepContentProps = {
  answers: OnboardingAnswers;
  currentStep: number;
  updateAnswer: <Key extends keyof OnboardingAnswers>(
    key: Key,
    value: OnboardingAnswers[Key],
  ) => void;
};

function StepContent({ answers, currentStep, updateAnswer }: StepContentProps) {
  if (currentStep === 0) {
    return (
      <section className="step-content" aria-labelledby="welcome-title">
        <p className="step-kicker">Passo 1</p>
        <h2 id="welcome-title">Sua energia conta. Aqui ela e o ponto de partida.</h2>
        <p className="lede">
          Vou aprender com voce nas proximas semanas. Por agora, so preciso do
          suficiente para respeitar sua energia.
        </p>
        <div className="promise-grid" aria-label="O que acontece agora">
          <span>6 passos curtos</span>
          <span>Voltar sempre disponivel</span>
          <span>Skip sem punicao</span>
        </div>
      </section>
    );
  }

  if (currentStep === 1) {
    return (
      <section className="step-content" aria-labelledby="identity-title">
        <p className="step-kicker">Passo 2</p>
        <h2 id="identity-title">Como voce quer ser chamado aqui?</h2>
        <p className="lede">Use o nome que deixa a interface mais sua.</p>
        <label className="field">
          <span>Nome ou apelido</span>
          <input
            required
            aria-describedby="name-help"
            autoComplete="given-name"
            value={answers.nome}
            onChange={(event) => updateAnswer("nome", event.target.value)}
          />
          <small id="name-help">Esse campo personaliza a sua experiencia.</small>
        </label>
        <label className="field">
          <span>Timezone</span>
          <input
            value={answers.timezone}
            onChange={(event) => updateAnswer("timezone", event.target.value)}
          />
        </label>
      </section>
    );
  }

  if (currentStep === 2) {
    return (
      <section className="step-content" aria-labelledby="objective-title">
        <p className="step-kicker">Passo 3</p>
        <h2 id="objective-title">O que voce mais quer organizar agora?</h2>
        <p className="lede">
          Escolha um foco inicial. Da para ajustar depois no perfil.
        </p>
        <fieldset className="choice-grid">
          <legend className="sr-only">Objetivo principal</legend>
          {objectiveChoices.map((choice) => (
            <label className="choice-card" key={choice.value}>
              <input
                checked={answers.objetivo_principal === choice.value}
                name="objetivo_principal"
                type="radio"
                value={choice.value}
                onChange={() =>
                  updateAnswer("objetivo_principal", choice.value)
                }
              />
              <strong>{choice.label}</strong>
              <span>{choice.hint}</span>
            </label>
          ))}
        </fieldset>
      </section>
    );
  }

  if (currentStep === 3) {
    return (
      <section className="step-content" aria-labelledby="routine-title">
        <p className="step-kicker">Passo 4</p>
        <h2 id="routine-title">Quando sua rotina e energia costumam aparecer?</h2>
        <p className="lede">Nao precisa ser perfeito. O Orb ajusta com o uso.</p>
        <div className="time-grid">
          <label className="field">
            <span>Inicio da rotina</span>
            <input
              type="time"
              value={answers.horario_primeiro_check_in}
              onChange={(event) =>
                updateAnswer("horario_primeiro_check_in", event.target.value)
              }
            />
          </label>
          <label className="field">
            <span>Fim da rotina</span>
            <input
              type="time"
              value={answers.horario_ultimo_check_in}
              onChange={(event) =>
                updateAnswer("horario_ultimo_check_in", event.target.value)
              }
            />
          </label>
        </div>
        <fieldset className="chip-group">
          <legend>Janelas de pico</legend>
          {peakWindowChoices.map((choice) => (
            <label className="chip" key={choice.value}>
              <input
                checked={answers.janelas_pico.includes(choice.value)}
                type="checkbox"
                value={choice.value}
                onChange={() =>
                  updateAnswer(
                    "janelas_pico",
                    toggleList(answers.janelas_pico, choice.value, [
                      "ainda_nao_sei",
                      "varia_muito",
                    ]),
                  )
                }
              />
              <span>{choice.label}</span>
            </label>
          ))}
        </fieldset>
        <fieldset className="chip-group">
          <legend>Quando costuma ficar mais dificil comecar?</legend>
          {lowWindowChoices.map((choice) => (
            <label className="chip" key={choice.value}>
              <input
                checked={answers.janelas_baixa_energia.includes(choice.value)}
                type="checkbox"
                value={choice.value}
                onChange={() =>
                  updateAnswer(
                    "janelas_baixa_energia",
                    toggleList(
                      answers.janelas_baixa_energia,
                      choice.value,
                      ["ainda_nao_sei"],
                    ),
                  )
                }
              />
              <span>{choice.label}</span>
            </label>
          ))}
        </fieldset>
      </section>
    );
  }

  return (
    <section className="step-content" aria-labelledby="triggers-title">
      <p className="step-kicker">Passo 5</p>
      <h2 id="triggers-title">O que costuma drenar voce?</h2>
      <p className="lede">
        Isso ajuda o Orb a sugerir com mais cuidado. Nao e diagnostico.
      </p>
      <fieldset className="chip-group">
        <legend>Gatilhos de drenagem</legend>
        {triggerChoices.map((choice) => (
          <label className="chip" key={choice.value}>
            <input
              checked={answers.gatilhos.includes(choice.value)}
              type="checkbox"
              value={choice.value}
              onChange={() =>
                updateAnswer(
                  "gatilhos",
                  toggleList(answers.gatilhos, choice.value, ["nenhum"]),
                )
              }
            />
            <span>{choice.label}</span>
          </label>
        ))}
      </fieldset>
      <fieldset className="choice-grid choice-grid-compact">
        <legend>Quanto o ambiente pesa na sua rotina?</legend>
        {sensitivityChoices.map((choice) => (
          <label className="choice-card" key={choice.value}>
            <input
              checked={answers.sensibilidade === choice.value}
              name="sensibilidade"
              type="radio"
              value={choice.value}
              onChange={() => updateAnswer("sensibilidade", choice.value)}
            />
            <strong>{choice.label}</strong>
            <span>{choice.hint}</span>
          </label>
        ))}
      </fieldset>
    </section>
  );
}

type ResultStepProps = {
  creationMode: CreationMode | null;
  draftSaved: boolean;
  draftTitle: string;
  onBack: () => void;
  onCreate: (mode: CreationMode) => void;
  onDraftTitleChange: (title: string) => void;
  onSaveDraft: (event: FormEvent<HTMLFormElement>) => void;
  profile: InitialProfile;
};

function ResultStep({
  creationMode,
  draftSaved,
  draftTitle,
  onBack,
  onCreate,
  onDraftTitleChange,
  onSaveDraft,
  profile,
}: ResultStepProps) {
  const curve = curveForProfile(profile);
  const visibleTriggers =
    profile.gatilhos.length === 0
      ? ["sem gatilhos declarados"]
      : profile.gatilhos.slice(0, 3).map(formatToken);

  return (
    <section className="result-grid" aria-labelledby="result-title">
      <article className="result-card">
        <p className="step-kicker">Passo 6</p>
        <h2 id="result-title">Este e seu Perfil Energetico inicial.</h2>
        <p className="lede">
          Este e um primeiro desenho. O Orb ajusta com seus check-ins e com o
          que acontecer na rotina.
        </p>

        <div className="archetype-panel">
          <span>Arquetipo</span>
          <strong>{profile.arquetipo}</strong>
          <p>
            Sua energia foi desenhada com confianca {profile.confianca_inicial}.
            A versao oficial continua no servidor.
          </p>
        </div>

        <div
          className="energy-curve"
          role="img"
          aria-label={`Curva inicial de energia com confianca ${profile.confianca_inicial}`}
        >
          {curve.map((period) => (
            <span className="curve-column" key={period.key}>
              <span
                className="curve-bar"
                style={
                  { "--bar-height": `${period.height}%` } as CSSProperties
                }
              />
              <span>{period.label}</span>
            </span>
          ))}
        </div>

        <dl className="profile-summary">
          <div>
            <dt>Rotina</dt>
            <dd>
              {profile.horario_primeiro_check_in} -{" "}
              {profile.horario_ultimo_check_in}
            </dd>
          </div>
          <div>
            <dt>Janelas</dt>
            <dd>{formatList(profile.janelas_pico)}</dd>
          </div>
          <div>
            <dt>Gatilhos</dt>
            <dd>{visibleTriggers.join(", ")}</dd>
          </div>
          <div>
            <dt>Tom</dt>
            <dd>Acolhedor, com notificacao equilibrada</dd>
          </div>
        </dl>

        <nav className="actions" aria-label="Primeira acao guiada">
          <button className="secondary-button" type="button" onClick={onBack}>
            Voltar
          </button>
          <button
            className="primary-button"
            type="button"
            onClick={() => onCreate("task")}
          >
            Criar tarefa
          </button>
          <button
            className="primary-button alt"
            type="button"
            onClick={() => onCreate("event")}
          >
            Criar evento
          </button>
        </nav>
      </article>

      <article className="draft-card" aria-labelledby="draft-title">
        <h3 id="draft-title">
          {creationMode === "event" ? "Novo evento" : "Primeira acao"}
        </h3>
        {creationMode ? (
          <form onSubmit={onSaveDraft}>
            <label className="field">
              <span>
                {creationMode === "event"
                  ? "Titulo do evento"
                  : "Titulo da tarefa"}
              </span>
              <input
                required
                value={draftTitle}
                onChange={(event) => onDraftTitleChange(event.target.value)}
              />
            </label>
            <button className="secondary-button" type="submit">
              Preparar rascunho
            </button>
            {draftSaved && (
              <p className="draft-status" role="status">
                Rascunho preparado. A criacao oficial deve ser confirmada pela
                API de {creationMode === "event" ? "eventos" : "tarefas"}.
              </p>
            )}
          </form>
        ) : (
          <p>
            Escolha Criar tarefa ou Criar evento para abrir o primeiro rascunho
            sem perder o resultado do perfil.
          </p>
        )}
      </article>
    </section>
  );
}

function formatList(values: string[]) {
  if (values.length === 0) {
    return "ainda em observacao";
  }

  return values.map(formatToken).join(", ");
}

function formatToken(value: string) {
  return value.replaceAll("_", " ");
}
