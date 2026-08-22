# Fish completions for `sandvm` (see package.nix and docs/microvm-sandbox.md).
set -l subcommands new start stop rm ssh list ls resize

function __sandvm_names --description 'Known sandvm instance names'
    sandvm list 2>/dev/null | tail -n +2 | string match -r '^\S+'
end

complete -c sandvm -f

# Subcommands (only before one has been given).
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a new -d 'Create and start a sandbox'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a start -d 'Start an existing sandbox'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a stop -d 'Stop a running sandbox (state is kept)'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a rm -d 'Stop and delete a sandbox, storage and all (irreversible)'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a ssh -d 'SSH in, starting the sandbox first if needed'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a list -d 'List every sandbox and its state'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a resize -d 'Grow a sandbox'\''s disks'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a '(__fish_complete_directories)' -d 'Folder shorthand'

# Instance names.
complete -c sandvm -n "__fish_seen_subcommand_from start stop rm ssh resize" -a '(__sandvm_names)' -d Sandbox

# new/start options.
complete -c sandvm -n "__fish_seen_subcommand_from new" -l type -x -a 'minimal generic devenv workstation' -d 'Guest flavour (default devenv)'
complete -c sandvm -n "__fish_seen_subcommand_from new" -l workspace -r -a '(__fish_complete_directories)' -d 'Host folder to mount at /workspace'
complete -c sandvm -n "__fish_seen_subcommand_from new start" -l cpu -x -d 'vCPU count (default 4)'
complete -c sandvm -n "__fish_seen_subcommand_from new start" -l mem -x -d 'Memory ceiling in MiB (default 32768; the balloon returns unused RAM to the host)'
complete -c sandvm -n "__fish_seen_subcommand_from new start resize" -l disk -x -d 'Nix store overlay size in MiB (sparse; default 32768)'
complete -c sandvm -n "__fish_seen_subcommand_from new start resize" -l home-disk -x -d '/home/iosta size in MiB (sparse; default 16384)'
complete -c sandvm -n "__fish_seen_subcommand_from new start" -l port -x -d 'Forward an extra host<->guest TCP port (repeatable)'
complete -c sandvm -n "__fish_seen_subcommand_from new start" -s s -l ssh -d 'Wait for boot, then SSH straight in'
complete -c sandvm -n "__fish_seen_subcommand_from new start" -s f -l foreground -d 'Run attached to this terminal instead of in the background'
complete -c sandvm -n "__fish_seen_subcommand_from new start" -l fresh -d 'Rebuild the guest runner even if nothing changed'

complete -c sandvm -s h -l help -d 'Show usage'
