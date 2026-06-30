# Orb

Orb e um produto web individual para ajudar o usuario a responder, com seguranca e baixa carga cognitiva, a pergunta central: "o que eu faco agora?".

A fundacao escolhida para a v1 e Rails 8 API em `api/`, React/Vite TypeScript em `apps/web/`, contratos em `packages/contracts/`, worker Python em `apps/ml-worker/`, PostgreSQL, Solid Queue e Valkey/Redis.

## Trabalho Dentro Do Container

Todas as dependencias, builds e testes devem rodar dentro do container do repo. Quando o comando depender do ambiente carregado pelo terminal integrado, use `bash -ic`:

```sh
bash -ic 'make help'
bash -ic 'make bootstrap'
bash -ic 'make test'
```

Nao instale dependencias no host para fazer o projeto funcionar. Segredos ficam em variaveis de ambiente ou secret manager; arquivos `.env*` locais sao ignorados pelo Git, exceto exemplos seguros como `.env.example`.

## Comandos Oficiais

Preflight do container:

```sh
bash -ic 'command -v make'
bash -ic 'command -v rg'
bash -ic 'python3.13 --version'
```

Se `make` nao estiver disponivel, a imagem do container precisa ser corrigida antes de usar os alvos oficiais. Para diagnostico do runner red-first sem Makefile, rode `bash -ic 'bash tests/run.sh'`.

```sh
bash -ic 'make bootstrap'
```

Instala dependencias dos componentes que ja existirem. No estado inicial, alvos sem scaffold imprimem `skip` com a task pendente.

O worker ML usa Python `3.13.14`, declarado em `.python-version` e em `apps/ml-worker/pyproject.toml`. O bootstrap instala o pacote editavel com as dependencias fixadas do projeto: FastAPI `0.115.6`, Pydantic `2.12.5`, Polars `1.41.2`, scikit-learn `1.9.0` e pytest `8.3.4`.

```sh
bash -ic 'make bootstrap-ml'
bash -ic 'python3.13 -m pip show fastapi pydantic polars scikit-learn pytest'
```

```sh
bash -ic 'make test'
```

Roda a suite red-first em `tests/` e grava evidencias em `test-reports/`. Enquanto Fase 0 ainda estiver incompleta, esse comando pode falhar de forma esperada.

```sh
bash -ic 'make test-backend'
```

Roda as specs Rails/RSpec. A Sprint 2 depende de PostgreSQL acessivel com os defaults de `api/config/database.yml`: `POSTGRES_HOST=localhost`, `POSTGRES_USER=orb`, `POSTGRES_PASSWORD=orb`, `POSTGRES_TEST_DB=orb_test`. Antes da primeira execucao local, prepare o banco dentro do container:

```sh
bash -ic 'cd api && RAILS_ENV=test bundle exec ruby bin/rails db:prepare'
```

```sh
bash -ic 'make ci'
```

Roda os gates estritos de contratos, backend, build frontend e E2E. Este comando deve ficar verde antes de merge quando `api/`, `apps/web/` e `packages/contracts/` estiverem implementados.

```sh
bash -ic 'make build'
```

Executa checagens de build do backend e frontend.

```sh
bash -ic 'make dev-backend'
bash -ic 'make dev-frontend'
```

Sobem Rails API e Vite em terminais separados quando os scaffolds existirem.
O Vite encaminha `/api/*` para `http://127.0.0.1:3000`, entao o fluxo web usa
o mesmo origin do frontend com cookie opaco `_orb_session`. O frontend usa porta
estrita `5173`. Se a API avisar que ja existe `server.pid`, se a porta 5173
estiver ocupada ou se o navegador ainda mostrar UI antiga, confira e limpe os
servidores dev antigos antes de subir novamente:

```sh
bash -ic 'make dev-status'
bash -ic 'make dev-stop'
bash -ic 'make dev-backend'
bash -ic 'make dev-frontend'
```

O backend remove automaticamente um `tmp/pids/server.pid` stale quando o
processo Rails antigo ja morreu ou quando o PID foi reaproveitado por outro
processo.

## Validacao Local Sprint 1-3

1. Prepare o banco de desenvolvimento/teste conforme `api/config/database.yml`.
2. Em um terminal, rode `bash -ic 'make dev-backend'`.
3. Em outro terminal, rode `bash -ic 'make dev-frontend'`.
4. Abra `http://127.0.0.1:5173`.
5. Cadastre uma conta, confirme a tela de sessao inicial, siga para o
   onboarding resumido, conclua ou use `Explorar primeiro`.

Aceite minimo: cadastro rejeita senha fraca como `1234`, cadastro/login criam
sessao sem expor senha/token no JSON, reload restaura `GET /api/v1/auth/session`,
onboarding completo retorna perfil energetico/energia/primeira acao, skip cria
perfil neutro com retomada, e erros continuam no envelope seguro com
`correlation_id`.

## Validacao Local Sprint 4

1. Prepare o banco conforme `api/config/database.yml` e rode as migrations:

```sh
bash -ic 'cd api && RAILS_ENV=test bundle exec ruby bin/rails db:prepare'
```

2. Rode os gates automatizados:

```sh
bash -ic 'make test-contracts'
bash -ic 'make build-backend'
bash -ic 'make build-frontend'
bash -ic 'make test-e2e'
```

3. Se houver servidor antigo preso na porta, rode `bash -ic 'make dev-stop'`.
4. Com backend e frontend no ar, abra `http://127.0.0.1:5173`, entre ou crie
   uma conta, use a home `Hoje` para criar a tarefa `Produzir relatorio`, crie
   um evento, edite/conclua/adie/exclua a tarefa e confira o `Historico curto`.

Aceite minimo da Sprint 4: endpoints autenticados de tarefas/eventos nao abrem
sem sessao, itens pertencem ao usuario autenticado, update parcial preserva
campos omitidos, exclusao some das views ativas com tombstone minimizado,
evento externo nao pode ser alterado/excluido sem consentimento explicito, Free
ve historico de 14 dias e Pro ve historico completo sem apagar dados no
downgrade.

## CI

O workflow em `.github/workflows/ci.yml` roda quatro gates:

- `red-first`: suite shell em `tests/run.sh`, com upload de `test-reports/`.
- `contracts`: valida `packages/contracts` via script do pacote ou checagens minimas de OpenAPI/fixtures.
- `backend`: prepara Postgres e Valkey, instala gems e roda RSpec ou `rails test`.
- `frontend`: instala dependencias web, roda build Vite e `test:e2e`.

O CI deve falhar para contrato quebrado, erro de tipo/build frontend, spec backend vermelha ou E2E vermelho. Falhas por diretorios ainda ausentes indicam tasks de scaffold pendentes, nao devem ser mascaradas.

## Status Red-First

As fontes de verdade ficam em `.docs/`, `tests/`, `test-reports/`, `Makefile` e neste README. Se implementacao, contrato e docs divergirem, atualize o contrato/teste/documentacao junto da mudanca de codigo.

Para a Sprint 1, as tasks deste agente cobrem:

- F0-08: CI minimo para contratos, backend, frontend e E2E.
- F0-09: `.gitignore` e scripts locais para artefatos de build/teste.
- F0-10: comandos reproduziveis de bootstrap, teste, build e dev.

Para a Sprint 2, a base cobre:

- F0-11 a F0-13: envelope de erro, correlation id e `X-Orb-Source` canonico.
- F0-14 e F0-15: auth basico web com sessao opaca e isolamento por `policy_scope`.
- F0-16: guardrail Teams sem UI para bloquear energia individual em contexto organizacional.
- F0-17 a F0-20: entidades centrais, event recorder persistente, sanitizer e policies base.

## Privacidade Operacional

Logs, erros, relatorios e artefatos de CI nao devem carregar prompts completos, check-ins brutos, neurodivergencia livre, tokens, segredos ou dados financeiros desnecessarios. O plano Free deve continuar funcional sem LLM, e falhas de terceiros precisam ter fallback ou erro recuperavel.
