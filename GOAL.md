# AON infrastructure goals

I will be outlining my goals relating to running sandboxed containers for LLM Agents.

> **Historical note (2026-09-08):** written while df used **omp** and **paseo**. Both were dropped from the repo on
> 2026-09-08 in favour of `pi` + `herdr`; where this file names them, read the goal, not the tool.

- My host machine is `abhaile` with the main user `df`
- Guest machines are microvms with naming pattern `scoite-X`, all with the minimal user `iosta`.

Review the following sections and break the goals into logical steps that are tracked in a task file. I want each item
to be run as a dedicated step with a clear verification performed before it is marked off. Only then can the next step
commence. Some items are already ready. There are several TODOs in TODO.md relating to sandvm that can be added to this
list of tasks.

## Scoite VM

This is a tool previously called `sandvm`. I want to rename it `scoite` with a short alias `sc`. VMs created with scoite
will follow the pattern `scoite-X`. X is the name of the directory it is launched from by default, but the user is
prompted to rename it one first run.

Features of scoite:

- Can be one of 2 types of VM (changed from current `sandvm`):
  - minimal: bare-bones VM with internet access
  - dev:
    - default type
    - has python, node, headless chromium pre-installed and the expected shell/git tools
    - has OMP loaded with the host configuration
    - has Paseo daemon server installed (with a nix overlay described in this PR:
      https://github.com/getpaseo/paseo/pull/3250/changes) and running
    - will launch direnv/devenv.sh, install any dependencies
- Copy the existing features of the existing `sandvm` tool
- In addition to the exisiting `sandvm list` output, also include the DNS name of the VM, not just IP address.
- Ability to rename the instance name while running; have it reflected in the host machine so `ssh scoite-X` just works,
  and resolving DNS (e.g `https://scoite-X.local:5173`) just works.
- Able to expose VM services externally (eg. Vite web app (:5173); paseo daemon (:6767))
- Defaults to `/workspace` folder when SSH into the machine
- Ability to connect to the llama.cpp instance on the host machine for chatting with local models (already part of
  sandvm)

## Abhaile Host

Aside from the existing workstation tools, I want the host machine to exhibit the following behaviours:

- Able to run the `paseo-desktop` app.
- Able to login to various model providers (Anthropic, OpenRouter, etc) with `omp auth-broker` tool and make the
  credentials/keys available to valid `scoite VM`. The auth tokens may expire (e.g not refreshed in time due to machine
  being asleep) or be removed/reset. The tool should try to keep the API keys available and refreshed. Any changes
  should be propagated into the `scoite VM`s,
- Able to share existing SSH Keys with a `scoite VM` and have any changes propagated into the VM similar to the Auth
  tokens.
- Able to share an existing OMP (oh-my-pi) configuration into each `scoite VM` and for it to be used correctly there and
  have any changes propagated into the VM similar to the Auth tokens.
- Able to share the main Nix store on the machine so any packages aren't re-downloaded.
- Able to connect to a `scoite VM` using local domain names and not just IP addresses.
