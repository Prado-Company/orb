import type { FormEvent } from "react";
import { useState } from "react";
import {
  login,
  signUp,
  type AuthSessionResponse,
  type LoginInput,
  type SignUpInput,
} from "../../lib/orbApi";

type AuthMode = "sign_up" | "login";

type AuthPanelProps = {
  initialMessage?: string;
  onAuthenticated: (session: AuthSessionResponse) => void;
};

export function AuthPanel({
  initialMessage,
  onAuthenticated,
}: AuthPanelProps) {
  const [mode, setMode] = useState<AuthMode>("sign_up");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [timezone, setTimezone] = useState(
    Intl.DateTimeFormat().resolvedOptions().timeZone || "America/Sao_Paulo",
  );
  const [status, setStatus] = useState<
    { kind: "idle" } | { kind: "pending" } | { kind: "error"; message: string }
  >({ kind: "idle" });

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (mode === "sign_up" && !isStrongPassword(password)) {
      setStatus({
        kind: "error",
        message:
          "Use uma senha com pelo menos 12 caracteres, incluindo letras e numeros.",
      });
      return;
    }

    setStatus({ kind: "pending" });

    try {
      const session =
        mode === "sign_up"
          ? await signUp(buildSignUpInput())
          : await login(buildLoginInput());
      onAuthenticated(session);
    } catch (error) {
      setStatus({
        kind: "error",
        message:
          error instanceof Error
            ? error.message
            : "Nao foi possivel entrar agora.",
      });
    }
  }

  function buildSignUpInput(): SignUpInput {
    return {
      name: name.trim(),
      email: email.trim(),
      password,
      timezone: timezone.trim() || "America/Sao_Paulo",
      locale: "pt-BR",
    };
  }

  function buildLoginInput(): LoginInput {
    return {
      email: email.trim(),
      password,
    };
  }

  return (
    <main className="app-shell auth-shell" aria-labelledby="auth-title">
      <section className="auth-panel">
        <div className="auth-copy">
          <p className="eyebrow">Sprint 1-3</p>
          <h1 id="auth-title">Orb</h1>
          <p>
            Cadastre ou entre para validar a sessao inicial e seguir para o
            onboarding resumido.
          </p>
        </div>

        <form className="auth-card" onSubmit={handleSubmit}>
          <div className="mode-tabs" role="tablist" aria-label="Acesso">
            <button
              aria-selected={mode === "sign_up"}
              className={mode === "sign_up" ? "mode-tab active" : "mode-tab"}
              role="tab"
              type="button"
              onClick={() => setMode("sign_up")}
            >
              Criar conta
            </button>
            <button
              aria-selected={mode === "login"}
              className={mode === "login" ? "mode-tab active" : "mode-tab"}
              role="tab"
              type="button"
              onClick={() => setMode("login")}
            >
              Entrar
            </button>
          </div>

          {initialMessage && status.kind === "idle" && (
            <p className="inline-note" role="status">
              {initialMessage}
            </p>
          )}

          {status.kind === "error" && (
            <p className="error-banner" role="alert">
              {status.message}
            </p>
          )}

          {mode === "sign_up" && (
            <label className="field">
              <span>Nome</span>
              <input
                required
                autoComplete="given-name"
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </label>
          )}

          <label className="field">
            <span>Email</span>
            <input
              required
              autoComplete="email"
              inputMode="email"
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
          </label>

          <label className="field">
            <span>Senha</span>
            <input
              required
              aria-describedby={mode === "sign_up" ? "password-help" : undefined}
              autoComplete={mode === "sign_up" ? "new-password" : "current-password"}
              minLength={mode === "sign_up" ? 12 : undefined}
              pattern={mode === "sign_up" ? "^(?=.*[A-Za-z])(?=.*\\d).{12,}$" : undefined}
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
            {mode === "sign_up" && (
              <small id="password-help">
                Use uma senha com pelo menos 12 caracteres, incluindo letras e numeros.
              </small>
            )}
          </label>

          {mode === "sign_up" && (
            <label className="field">
              <span>Timezone</span>
              <input
                required
                value={timezone}
                onChange={(event) => setTimezone(event.target.value)}
              />
            </label>
          )}

          <button
            className="primary-button"
            disabled={status.kind === "pending"}
            type="submit"
          >
            {status.kind === "pending"
              ? "Confirmando..."
              : mode === "sign_up"
                ? "Criar conta"
                : "Entrar"}
          </button>
        </form>
      </section>
    </main>
  );
}

function isStrongPassword(password: string) {
  return (
    password.length >= 12 &&
    /[A-Za-z]/.test(password) &&
    /\d/.test(password)
  );
}
