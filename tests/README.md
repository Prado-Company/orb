# Orb App Tests

Suite red-first criada antes da implementacao do produto.

Ela transforma os documentos em `.docs/` em testes executaveis de aceite, contrato e operacao para cobrir de `Fase 0: Fundacao executavel` ate `v1 publica`.

## Como rodar

```sh
bash tests/run.sh
```

Se `make` estiver instalado, tambem funciona:

```sh
make test
```

## Relatorios

Os relatorios sao gerados em `test-reports/`, pasta ignorada pelo Git:

- `test-reports/summary.md`
- `test-reports/results.json`
- `test-reports/junit.xml`
- `test-reports/red-first-todo.md`
- `test-reports/cases/*.log`

## Mentalidade TDD

O estado esperado inicial e vermelho. Como ainda nao existe Rails, Vite, contratos OpenAPI ou dominio implementado, a maioria dos testes deve falhar com mensagens objetivas. Cada falha representa o proximo contrato a implementar.
