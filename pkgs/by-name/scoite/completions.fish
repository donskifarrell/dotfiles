# Fish completions for `scoite` (see package.nix and docs/microvm-sandbox.md).
set -l subcommands new start stop rm rename mv ssh list ls resize expose unexpose

function __scoite_names --description 'Known scoite instance names'
    scoite list 2>/dev/null | tail -n +2 | string match -r '^\S+'
end

complete -c scoite -f

# Subcommands (only before one has been given).
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a new -d 'Create and start a sandbox'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a start -d 'Start an existing sandbox'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a stop -d 'Stop a running sandbox (state is kept)'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a rm -d 'Stop and delete a sandbox, storage and all (irreversible)'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a rename -d 'Rename a sandbox (no restart needed)'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a ssh -d 'SSH in, starting the sandbox first if needed'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a list -d 'List every sandbox and its state'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a resize -d 'Grow a sandbox'\''s disks'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a expose -d 'Forward a port into a running sandbox (no restart)'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a unexpose -d 'Stop forwarding a port'
complete -c scoite -n "not __fish_seen_subcommand_from $subcommands" -a '(__fish_complete_directories)' -d 'Folder shorthand'

# Instance names.
complete -c scoite -n "__fish_seen_subcommand_from start stop rm rename ssh resize expose unexpose" -a '(__scoite_names)' -d Sandbox

# new/start options.
complete -c scoite -n "__fish_seen_subcommand_from new" -l name -x -d 'Name the sandbox (default: the workspace folder name)'
complete -c scoite -n "__fish_seen_subcommand_from new" -l type -x -a 'minimal dev' -d 'Guest flavour (default dev)'
complete -c scoite -n "__fish_seen_subcommand_from new" -l workspace -r -a '(__fish_complete_directories)' -d 'Host folder to mount at /workspace'
complete -c scoite -n "__fish_seen_subcommand_from new start" -l cpu -x -d 'vCPU count (default 4)'
complete -c scoite -n "__fish_seen_subcommand_from new start" -l mem -x -d 'Memory ceiling in MiB (default 32768; the balloon returns unused RAM to the host)'
complete -c scoite -n "__fish_seen_subcommand_from new start resize" -l disk -x -d 'Nix store overlay size in MiB (sparse; default 32768)'
complete -c scoite -n "__fish_seen_subcommand_from new start resize" -l home-disk -x -d '/home/iosta size in MiB (sparse; default 16384)'
complete -c scoite -n "__fish_seen_subcommand_from new start" -l port -x -d 'Forward an extra host<->guest TCP port (repeatable)'
complete -c scoite -n "__fish_seen_subcommand_from new start" -s s -l ssh -d 'Wait for boot, then SSH straight in'
complete -c scoite -n "__fish_seen_subcommand_from new start" -s f -l foreground -d 'Run attached to this terminal instead of in the background'
complete -c scoite -n "__fish_seen_subcommand_from new start" -l fresh -d 'Rebuild the guest runner even if nothing changed'

complete -c scoite -s h -l help -d 'Show usage'
