SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
PYTHON ?= python3.13
DEV_BACKEND_PORT ?= 3000
DEV_FRONTEND_PORT ?= 5173

.PHONY: help bootstrap bootstrap-backend bootstrap-frontend bootstrap-contracts bootstrap-ml \
	test test-red test-contracts test-backend test-frontend test-e2e \
	build build-backend build-frontend dev dev-status dev-stop dev-backend dev-frontend ci

help:
	@printf 'Orb commands (run inside the container with bash -ic):\n'
	@printf '  make bootstrap          Install available workspace dependencies\n'
	@printf '  make test               Run the red-first shell suite\n'
	@printf '  make ci                 Run contracts, backend, frontend build and E2E gates\n'
	@printf '  make build              Run backend and frontend build checks\n'
	@printf '  make dev-backend        Start Rails API when api/ exists\n'
	@printf '  make dev-frontend       Start Vite web when apps/web exists\n'
	@printf '  make dev-status         Show listeners for Rails/Vite dev ports\n'
	@printf '  make dev-stop           Stop Rails/Vite dev listeners for this container\n'

bootstrap: bootstrap-backend bootstrap-frontend bootstrap-contracts bootstrap-ml

bootstrap-backend:
	@if [[ -f api/Gemfile ]]; then \
		cd api; \
		bundle install; \
	else \
		printf 'skip bootstrap-backend: api/Gemfile not found (F0-01 pending).\n'; \
	fi

bootstrap-frontend:
	@if [[ -f apps/web/package.json ]]; then \
		corepack enable; \
		cd apps/web; \
		pnpm install --frozen-lockfile; \
	else \
		printf 'skip bootstrap-frontend: apps/web/package.json not found (F0-02 pending).\n'; \
	fi

bootstrap-contracts:
	@if [[ -f packages/contracts/package.json ]]; then \
		corepack enable; \
		cd packages/contracts; \
		pnpm install --frozen-lockfile; \
	else \
		printf 'skip bootstrap-contracts: packages/contracts/package.json not found.\n'; \
	fi

bootstrap-ml:
	@if [[ -f apps/ml-worker/pyproject.toml ]]; then \
		cd apps/ml-worker; \
		$(PYTHON) -m pip install -e '.[dev]'; \
	else \
		printf 'skip bootstrap-ml: apps/ml-worker/pyproject.toml not found (F0-04 pending).\n'; \
	fi

test:
	bash tests/run.sh

test-red: test

test-contracts:
	@if [[ -f packages/contracts/package.json ]]; then \
		cd packages/contracts; \
		pnpm test; \
	else \
		test -f packages/contracts/openapi.yaml || { printf 'missing packages/contracts/openapi.yaml\n'; exit 1; }; \
		test -d packages/contracts/fixtures || { printf 'missing packages/contracts/fixtures\n'; exit 1; }; \
		rg -q 'correlation_id' packages/contracts/openapi.yaml || { printf 'OpenAPI must include correlation_id\n'; exit 1; }; \
		rg -q 'event|evento' packages/contracts/fixtures || { printf 'contract fixtures must include event examples\n'; exit 1; }; \
		rg -q 'error|erro' packages/contracts/fixtures || { printf 'contract fixtures must include error examples\n'; exit 1; }; \
	fi

test-backend:
	@test -f api/Gemfile || { printf 'missing api/Gemfile\n'; exit 1; }
	@cd api; \
	if [[ -d spec ]]; then \
		bundle exec rspec; \
	else \
		bundle exec ruby bin/rails test; \
	fi

test-frontend:
	@test -f apps/web/package.json || { printf 'missing apps/web/package.json\n'; exit 1; }
	@cd apps/web; \
	if pnpm run | rg -q '^  test'; then \
		pnpm test; \
	else \
		printf 'skip test-frontend: package.json has no test script.\n'; \
	fi

test-e2e:
	@test -f apps/web/package.json || { printf 'missing apps/web/package.json\n'; exit 1; }
	@cd apps/web; pnpm test:e2e

build: build-backend build-frontend

build-backend:
	@test -f api/Gemfile || { printf 'missing api/Gemfile\n'; exit 1; }
	@cd api; bundle exec ruby bin/rails zeitwerk:check

build-frontend:
	@test -f apps/web/package.json || { printf 'missing apps/web/package.json\n'; exit 1; }
	@cd apps/web; pnpm build

dev:
	@printf 'Use two terminals inside the container:\n'
	@printf '  bash -ic "make dev-backend"\n'
	@printf '  bash -ic "make dev-frontend"\n'
	@printf 'If ports are already occupied, run:\n'
	@printf '  bash -ic "make dev-status"\n'
	@printf '  bash -ic "make dev-stop"\n'

dev-status:
	@printf 'Rails API port %s:\n' "$(DEV_BACKEND_PORT)"
	@if ruby -rsocket -e 'port = Integer(ARGV[0]); TCPSocket.new("127.0.0.1", port).close' "$(DEV_BACKEND_PORT)" 2>/dev/null; then \
		printf '  listening on http://127.0.0.1:%s\n' "$(DEV_BACKEND_PORT)"; \
	else \
		printf '  no listener\n'; \
	fi
	@ps -eo pid=,command= 2>/dev/null | rg 'rails server|bin/rails|puma' | rg -v 'rg |ps -eo|bash -eu' || true
	@printf 'Vite web port %s:\n' "$(DEV_FRONTEND_PORT)"
	@if ruby -rsocket -e 'port = Integer(ARGV[0]); TCPSocket.new("127.0.0.1", port).close' "$(DEV_FRONTEND_PORT)" 2>/dev/null; then \
		printf '  listening on http://127.0.0.1:%s\n' "$(DEV_FRONTEND_PORT)"; \
	else \
		printf '  no listener\n'; \
	fi
	@ps -eo pid=,command= 2>/dev/null | rg 'vite|pnpm dev' | rg -v 'rg |ps -eo|bash -eu' || true

dev-stop:
	@printf 'Stopping Rails API dev server on port %s when present...\n' "$(DEV_BACKEND_PORT)"
	@if [[ -f api/tmp/pids/server.pid ]]; then \
		pid="$$(cat api/tmp/pids/server.pid)"; \
		if [[ -n "$$pid" ]] && kill -0 "$$pid" 2>/dev/null; then \
			kill "$$pid" 2>/dev/null || true; \
			printf '  stopped Rails pid %s\n' "$$pid"; \
		fi; \
		rm -f api/tmp/pids/server.pid; \
	fi
	@printf 'Stopping Vite dev server on port %s when present...\n' "$(DEV_FRONTEND_PORT)"
	@if command -v fuser >/dev/null; then \
		fuser -k "$(DEV_FRONTEND_PORT)/tcp" 2>/dev/null || true; \
	else \
		pids="$$(ps -eo pid=,command= 2>/dev/null | awk '/vite|pnpm dev/ && $$0 !~ /awk|make dev-stop|bash -eu|ps -eo/ { print $$1 }')"; \
		if [[ -n "$$pids" ]]; then \
			kill $$pids 2>/dev/null || true; \
			printf '  stopped Vite-like pid(s): %s\n' "$$pids"; \
		else \
			printf '  no Vite-like process found\n'; \
		fi; \
	fi

dev-backend:
	@test -f api/Gemfile || { printf 'missing api/Gemfile\n'; exit 1; }
	@cd api; \
	if [[ -f tmp/pids/server.pid ]]; then \
		pid="$$(cat tmp/pids/server.pid)"; \
		if [[ -n "$$pid" ]] && kill -0 "$$pid" 2>/dev/null; then \
			cmd="$$(ps -p "$$pid" -o command= 2>/dev/null || true)"; \
			if [[ "$$cmd" == *"rails server"* || "$$cmd" == *"bin/rails"* || "$$cmd" == *"puma"* ]]; then \
				printf 'Rails API already running on port %s (pid %s). Use make dev-stop to restart it.\n' "$${PORT:-$(DEV_BACKEND_PORT)}" "$$pid"; \
				exit 0; \
			fi; \
			printf 'removing stale Rails pid file reused by another process: tmp/pids/server.pid\n'; \
			rm -f tmp/pids/server.pid; \
		else \
			printf 'removing stale Rails pid file: tmp/pids/server.pid\n'; \
			rm -f tmp/pids/server.pid; \
		fi; \
	fi; \
	bundle exec ruby bin/rails server -b 0.0.0.0 -p $${PORT:-$(DEV_BACKEND_PORT)}

dev-frontend:
	@test -f apps/web/package.json || { printf 'missing apps/web/package.json\n'; exit 1; }
	@if ruby -rsocket -e 'port = Integer(ARGV[0]); TCPSocket.new("127.0.0.1", port).close' "$${PORT:-$(DEV_FRONTEND_PORT)}" 2>/dev/null; then \
		printf 'Vite web port %s is already in use. Open http://127.0.0.1:%s or run make dev-stop before restarting.\n' "$${PORT:-$(DEV_FRONTEND_PORT)}" "$${PORT:-$(DEV_FRONTEND_PORT)}"; \
		exit 0; \
	fi
	@cd apps/web; pnpm dev -- --port $${PORT:-$(DEV_FRONTEND_PORT)}

ci: bootstrap test-contracts test-backend build-frontend test-e2e
