import { useEffect, useState } from "react";
import { AuthPanel } from "./features/auth/AuthPanel";
import {
  OnboardingFlow,
  type InitialProfile,
  type OnboardingStateChange,
} from "./features/onboarding/OnboardingFlow";
import { SessionPanel } from "./features/session/SessionPanel";
import {
  loadSession,
  logoutSession,
  type AuthSessionResponse,
} from "./lib/orbApi";

type View = "session" | "onboarding";

export function App() {
  const [session, setSession] = useState<AuthSessionResponse | null>(null);
  const [view, setView] = useState<View>("session");
  const [lastProfile, setLastProfile] = useState<InitialProfile | null>(null);
  const [bootState, setBootState] = useState<
    | { kind: "checking" }
    | { kind: "ready" }
    | { kind: "guest"; message?: string }
  >({ kind: "checking" });

  useEffect(() => {
    const controller = new AbortController();

    loadSession(controller.signal)
      .then((nextSession) => {
        setSession(nextSession);
        setBootState({ kind: "ready" });
      })
      .catch((error) => {
        if (controller.signal.aborted) {
          return;
        }

        setBootState({
          kind: "guest",
          message:
            error instanceof Error && error.message
              ? error.message
              : "Entre para iniciar uma nova sessao.",
        });
      });

    return () => controller.abort();
  }, []);

  async function handleLogout() {
    try {
      await logoutSession();
    } catch {
      // A sessao local pode ser limpa mesmo se a API ja tiver revogado o cookie.
    }

    setSession(null);
    setLastProfile(null);
    setView("session");
    setBootState({ kind: "guest" });
  }

  function handleAuthenticated(nextSession: AuthSessionResponse) {
    setSession(nextSession);
    setView("session");
    setBootState({ kind: "ready" });
  }

  function handleOnboardingFinished(change: OnboardingStateChange) {
    setLastProfile(change.profile);
    setSession((current) =>
      current
        ? {
            ...current,
            user: {
              ...current.user,
              onboarding: {
                state: change.state,
                current_step: 6,
                total_steps: 6,
                resume_available: change.state === "pulado",
              },
            },
          }
        : current,
    );
  }

  if (bootState.kind === "checking") {
    return (
      <main className="app-shell loading-shell" aria-labelledby="loading-title">
        <section className="session-card">
          <p className="eyebrow">Sessao</p>
          <h1 id="loading-title">Validando sessao...</h1>
        </section>
      </main>
    );
  }

  if (!session) {
    return (
      <AuthPanel
        initialMessage={bootState.kind === "guest" ? bootState.message : undefined}
        onAuthenticated={handleAuthenticated}
      />
    );
  }

  if (view === "onboarding") {
    return (
      <OnboardingFlow
        session={session}
        onBackToSession={() => setView("session")}
        onFinished={handleOnboardingFinished}
        onLogout={handleLogout}
      />
    );
  }

  return (
    <SessionPanel
      lastProfile={lastProfile}
      session={session}
      onLogout={handleLogout}
      onStartOnboarding={() => setView("onboarding")}
    />
  );
}
