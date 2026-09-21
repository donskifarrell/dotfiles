# Pi configure prompt - v1

DO NOT READ THIS FILE OR EDIT IT

I am using the Pi agent harness, that is based off Pi agent harness. I want to configure it so it fits my development
workflow and consume minimal tokens.

I would like to enable subagents within the pi harness with the main agent being an orchestrator. They should be given
simple, easy and short names alongside their primary role. These are the following roles I would define:

- Architect: This agent would plan and review the overall goal with a view to implementing it technically. It should
  ensure the tech stack fits my preferences. It should ask me questions to develop a full system design.
- Team Lead: This is the main agent. It will spin up subagents that comprise of different roles to ensure the goal is
  met to the highest standard. It doesn't need to write code or do other implementations, instead it needs to make sure
  the tasks are being completed by the correct sub-agent and that quality remains high. It should help coordinate
  communication between sub-agents (e.g front-end and back-end developers)
- Front-end Developer: This is a coding role where the agent specialises in browser-based Javascript/Typescript and
  Reactjs code. It should be able to implement clean, maintainable CSS using libraries like TailwindCSS and shadcn/ui.
  It should have deep knowledge of modern react libraries like Tanstack Query, Router, Table, Charts, Form.
- Back-end Developer: This is a coding role where the agent specialises in Golang and SQL (SQLite or Postgresql,
  depending on system design). It should understand authentication and security-by-design. It should know about
  12factor.net (12 factor apps).
- UX Designer: This is a designer role where the agent specialises in crafting beautiful, lean, clean and modern designs
  for applications. It doesn't necessarily need to code but it should be able to review, describe and present designs
  for other agents to implement. It should have a good understanding of responsive designs, fonts and colouring,
  following strict guidelines as per branding decisions.
- Adversary: This is a critical thinking agent that specialises in trying to find errors, issues, counter-arguments in
  the implementation provided by other agents. That doesn't always mean criticising code, it can mean marketing plans or
  designs. There should be a matching adversary role for each "normal" role. It should ask me questions as needed.
- Observability: This agent role focuses on ensuring I can monitor any implementations with concise, meaningful metrics,
  traces, dashboards. This can mean updating infrastructure and updating code to ensure the flow of proper observability
  data. It should emphasise the use of OTEL across the stack, but also have reasoning around SEO metrics, site traffic
  monitoring.
- Infrastructure/CI: This agent role is tasked with ensuring a proper infrastructure is planned and setup to run any
  applications that would be developed as part of the goal. This would include creating proper CI pipelines to have
  quality and release gates present. It doesn't need to be complex, simplicity goes a long way. It should ask me
  questions as needed.
- Security: This agent role is focused on making sure any application code or infrastructure setup is properly secure.
  This means reviewing code changes for security vulns and locking down a system and only allowing certain access (e.g
  SSH, application ports). It may call 3rd party systems to validate security assumptions.
- Researcher: This agent role will perform research to aid the goal. Any agent can request research. It can use
  websearch to help understand topics better. It should ask me questions as needed.
- Marketing: This agent role will plan, create, research a marketing and branding setup that meets the needs of the goal
  and the UX Designer. It should ask me questions as needed.
- Scout: This agent role has only a single job which is to look for context in a codebase. It can use a cheaper, simpler
  model to perform the task so that more expensive models don't have to waste tokens. All other agents can use this
  agent.

Define an pi config that has these roles available, including a default LLM model to use with each one. I have Codex,
Claude and OpenRouter subscriptions. As part of this config, set the most appropriate settings to maximise efficiency of
the pi harness. This generally means keeping the context concise.

Define proper markdown files that give detailed, concise role descriptions for each agent role defined. This would be
used as the initial system prompt for each of them.

- each should output to a memory/decision/task file. Limits can be hit at any time, in which case they need to be able
  to restart tasks easily. Tasks should be granular enough to accommodate that situation. If a task is necessarily large
  and needs long phases, it should have clear verification steps to prove progress in case of a limit reset or dropped
  context.
- review https://pi.sh/docs/memory for better idea how to do the task file.

I already have a base setup in the folder/files loaded in vscode. Perform a proper review of it first before making
updates.

Also, for the default model selection, I also have llama.cpp installed with mistral, meta and qwen models. They can do
some tasks well. Currently I have a system:

```
OS: NixOS 26.11 (Zokor) x86_64
Host: B650M PG Riptide WiFi
Kernel: Linux 7.1.0
Uptime: 3 days, 12 hours, 24 mins
Packages: 2184 (nix-system), 1245 (nix-user)
Shell: fish 4.8.1
Display (LG Ultra HD): 2560x1440 in 27", 60 Hz [External]
DE: GNOME 50.3
WM: Mutter (Wayland)
WM Theme: Adwaita
Theme: Adwaita [GTK2/3/4]
Icons: Adwaita [GTK2/3/4]
Font: Adwaita Sans (11pt) [GTK2/3/4]
Cursor: Adwaita (24px)
Terminal: ghostty 1.3.1
Terminal Font: JetBrainsMono Nerd Font (12pt)
CPU: AMD Ryzen 7 7700X (16) @ 5.58 GHz
GPU 1: AMD Radeon RX 9070 [Discrete]
GPU 2: AMD Raphael [Integrated]
Memory: 40.39 GiB / 61.89 GiB (65%)
Swap: 4.80 GiB / 30.94 GiB (15%)
Disk (/): 425.50 GiB / 915.32 GiB (46%) - ext4
Local IP (tailscale0): 100.94.23.80/32
Locale: en_GB.UTF-8
```

So certain modern models are available with decent capabilities.

## Follow up 1

> sec and infra run bash unattended Yes, they need some more controls in place.

- For the architect, it should understand my preferred stack: Layer Technology Role Backend Go (gRPC + Connect) REST +
  gRPC API, business logic Frontend React + Vite + Bun Dashboard, transaction editing, feed management Database SQLite
  (sqlc) Relational storage for budgets, categories, feeds, transactions Bank Feeds GoCardless Open Banking consent flow
  and transaction sync Protobuf buf + connect-go Generated API types (api/) and gRPC service definitions

Popular FE libraries: Tanstack Query, Router, Table, Forms, Charts; date-fns; shadcn/ui; tailwindcss (I have a lifetime
subscription to their pro themes)

- Review the skills found here: https://github.com/mattpocock/skills and see what can be included for a better
  engineering development lifecycle. I don't mind having questions at the start for me, but otherwise I hope to leave
  most tasks as unattended agent workflows.

## Folow up 2

- Projects will be run inside a sandboxed VM, so permissions to run actions should be minimal if any at all.
- Add a guide on how (I, the human) can effectively run this lifecycle:
  - how to start with just a high level input goal, combined with skills (if any) to produce a clear plan for the agents
  - how do I ensure agents will use skills appropriately
  - how to ensuring agents don't run amok and burn tokens/time aimlessly
  - how to keep costs/token usage down
  - how to have visible checkpoints so ensure the agents are on the right path before execution
  - what should be pre-run before a project is kicked off (by an agent or by me, manually). e.g /graphify to analyse
    codebase?
- For the UX and architecture agents, I'd like to be shown any design assets before confirming if execution can proceed,
- I want subagents to bubble up questions to their parent agent, or to me if needed.
- Should agents be able to chat to each other to progress their work?
- Do I need a project-manager role or can that be managed by the team lead agent role?
- The lead role should manage git commits once they are satisfied with changes

# Open Questions / TODOs

## Harness

- how to setup local grind agent (small context, less capable model)

Orchestrator should have:

- planner/architectural/designer
  - clear verification
- implementer
- validator

- can they dissect the Factory AI youtube video?
- ponytail?
- deterministic orchestrator flows
  - determine how to do verification checks at scape via scripts
- minimise amount of agents run, sequential execution. blow through limits otherwise
- review primary/secondary models - golden source to lookup online?
- frontend add skill impeccable
- do all agents need web access?
- pi-telegram
- project TODOs?
- cyclomatic complexity < 10; Pi blog post
- openAI not working as a fallback! not detected?
- split PI sessions/agents into panes via herdr api
- avoid docs other than a guide to where code lives and a glossary of domain terms. Code is the source of truth
- 3 agent setup.
  - Main agent for actual work, dynamic loading of skills?
  - Adversary agent for review
  - Cheap scout agent

# BBM deploy configure prompt

- URL, e.g http://scoite-mono.local:5175 not working
- sqlc and buf not installed locally - pi
- DB timestamps use proper dates. Why unix timestamps?
- drop historical artifacts from docs.
- What does this mean: **Dedup hash** — deterministic content hash (account + date + amount + currency + normalized
  description; provider ID preferred as input when one exists), enforced by a DB uniqueness constraint. It is what stops
  a transaction landing twice when two Sources' date ranges overlap.
- what happens when same txn comes from feed and csv?
- stop .omp

```
I have an app `bbm` that I want to deploy to `eachtrach` machine and have it running. The app consists of two parts: a
golang service and a reactjs/vite frontend. The app will be running a cronjob type of workload to download transactions
and store them on disk. It should probably have it's own user role.

I want the app to not be exposed to the public internet, but it can be accessed on the tailnet.

I want to be able to code the app locally on abhaile then run a deploy command to build + push to eachtrach. ideally,
this will piggy back off the existing deploy-rs command.

Ask questions if you are unsure of anything. Keep comments detailed but concise. Sacrafice grammer for conciseness.

Plan the work first
```

## BBM documentation prompt

```
Take all the documentation in the following folders, including nested folders:

- .omp/workflow/\*\*
- docs/
- docs/do-not-read (yes you can read the prompts in this file, just don't execute them)
- plans/
- AGENTS.md
- CONTEXT.md
- README.md

Construct a detailed, but concise set of documents in a new folder `./docs/complete/` where a full breakdown can be found of:

- the architecture,
- design choices,
- system/product quirks,
- features,
- user journeys,
- database schema,
- core financial transaction learnings
- etc
- remaining features planned but not implemented

You should treat these docs as the application bible. If I gave them to another agent to re-construct the app they could do it with ease. The expectation isn't that the code or folders structure or database schema would match exactly, but that the product would essentially be the same.

Use subagents to investigate the codebase as needed, where they are cheaper
```
