DO NOT READ THIS FILE OR EDIT IT

I am using the oh-my-pi (omp) agent harness, that is based off Pi agent harness. I want to configure it so it fits my
development workflow and consume minimal tokens.

I would like to enable subagents within the omp harness with the main agent being an orchestrator. They should be given
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

Define an omp config that has these roles available, including a default LLM model to use with each one. I have Codex,
Claude and OpenRouter subscriptions. As part of this config, set the most appropriate settings to maximise efficiency of
the omp harness. This generally means keeping the context concise.

Define proper markdown files that give detailed, concise role descriptions for each agent role defined. This would be
used as the initial system prompt for each of them.

- each should output to a memory/decision/task file. Limits can be hit at any time, in which case they need to be able
  to restart tasks easily. Tasks should be granular enough to accommodate that situation. If a task is necessarily large
  and needs long phases, it should have clear verification steps to prove progress in case of a limit reset or dropped
  context.
- review https://omp.sh/docs/memory for better idea how to do the task file.
-

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

---

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

--

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

---

- drop herdr from being loaded in the host and guest vm. You don't need to remove the nix file, just disable it and
  remove any hooks.
- for the omp config, I have a dedicated sandbox config at ~/.omp/agent/config.sandbox.yml. That should be copied in
  along with the main config and the rest of the omp settings. The omp app should be launched with the config flag
  `--config ~/.omp/agent/config.sandbox.yml`
- in my host system, ping is behind sudo. Why is that? I should be able to run simple commands without root.
  > PING google.com (142.251.13.101): 56 data bytes ping: permission denied (are you root?)

---

evaluation warning: 'hiPrio' has been removed from pkgs, use `lib.hiPrio` instead evaluation warning: The option
`services.resolved.llmnr' defined in `nixos@virtualization/microvm-guest' has been renamed to
`services.resolved.settings.Resolve.LLMNR'.
