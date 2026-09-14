---
id: 001
slug: abhaile-observability
owner: infra
role: infra
status: DONE
created: 2026-09-13
updated: 2026-09-13
provider: openai-codex/gpt-5.6-terra
worker: worker-197aaf3e-1c8e-4d52-ac58-51bcdf0f9cec
session: run-e99d7efc-1800-48d9-b243-8927eafe96d9
review: approved
reviewer: adversary worker-410b9e48-511c-4fb6-a269-0e01d8d3e8b9
reviewProvider: openai-codex/gpt-5.6-sol
accepted: 2026-09-13T22:07:38Z
---

## Objective

Configure the NixOS observability stack on abhaile for BBM telemetry from eachtrach, following the BBM hand-off and the
user's selected rollout scope.

## Scope

In scope: full prod metrics/traces/logs from eachtrach; dev app metrics/traces plus node metrics from scoite-bbm (dev
stdout remains terminal-only by user choice); Prometheus/Grafana/Tempo/Loki on abhaile; dashboard; localhost-only
Grafana; host node metrics; docs/TODO and bbm lock as needed. Alert rules/Telegram deferred. No activation/deploy,
staging, commit, or writes outside repo.

## Acceptance criteria

Abhaile toplevel builds/evaluates with Prometheus (15s, 30d), Grafana datasources/dashboard, Tempo OTLP/HTTP and Loki
local retention; Grafana binds localhost; only telemetry ingest is network-reachable as needed; Prometheus targets prod,
dev, and localhost node exporter with env labels; eachtrach/dev guest wiring is coherent and does not violate scoite's
shared-closure invariant; BBM dashboard references the BBM input artifact; alerting is absent; narrow checks pass.

## Verification evidence

Latest infra worker: combined no-link builds for abhaile/eachtrach/scoite-dev pass; Caddy validates; Tempo config verify passes; Loki config validates; listener collision removed; Loki API local with push-only :3101 proxy; eachtrach Alloy URL updated; redundant firewall list removed. Final independent approval review pending.

## Blocker

The scoite-bbm dev process is manually launched, has no systemd bbm.service and no tailscale0. Full dev log shipping
cannot use the BBM NixOS module without either broad shared-guest services or changing the dev launch model. Need user
choice.

## Restart point

Latest blockers fixed and validated statically. Run one fresh independent review of current complete diff; if approved, record review then accept with existing evidence. No live rollout per user choice.

## Log

- 2026-09-13T20:19:20Z created owner=infra role=infra
- 2026-09-13T20:19:25Z status TODO -> BLOCKED
- 2026-09-13T20:20:59Z status BLOCKED -> IN_PROGRESS
- 2026-09-13T20:22:55Z status IN_PROGRESS -> BLOCKED
- 2026-09-13T20:28:16Z status BLOCKED -> IN_PROGRESS
- 2026-09-13T20:35:59Z status IN_PROGRESS -> SUBMITTED
- 2026-09-13T20:51:15Z review rejected by adversary worker-aaf543e1-18e4-495b-9c93-5818dd483ef1 (openai-codex/gpt-5.6-sol)
- 2026-09-13T20:56:04Z status IN_PROGRESS -> REVIEW
- 2026-09-13T21:36:05Z review rejected by adversary worker-0b77c63b-561e-4491-93d2-a1de5cb67d1a (openai-codex/gpt-5.6-sol)
- 2026-09-13T21:36:16Z status IN_PROGRESS -> IN_PROGRESS
- 2026-09-13T21:58:49Z status IN_PROGRESS -> REVIEW
- 2026-09-13T22:06:53Z review approved by adversary worker-410b9e48-511c-4fb6-a269-0e01d8d3e8b9 (openai-codex/gpt-5.6-sol)
- 2026-09-13T22:07:38Z accepted by parent: Task complete in repo. Runtime rollout and end-to-end smoke tests remain intentionally deferred, tracked in TODO.md with alerting/Telegram.
