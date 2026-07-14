# Fish completions for `sandvm` (see package.nix and docs/microvm-sandbox.md).
set -l subcommands stop rm list

function __sandvm_names --description 'Known sandvm instance names (the sandvm-<name> ssh alias form)'
    sandvm list 2>/dev/null | tail -n +2 | string match -r '^\S+'
end

complete -c sandvm -f

complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a stop -d 'Stop a running sandbox'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a rm -d 'Stop and delete a sandbox (irreversible)'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a list -d 'List known sandboxes'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -a '(__fish_complete_directories)'

complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -l port -x -d 'Forward an extra host<->guest TCP port (repeatable)'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -l cpu -x -d 'vCPU count (default 4)'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -l mem -x -d 'Memory ceiling in MB (default 32768; balloon returns unused RAM to the host)'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -s f -l foreground -d 'Run attached to this terminal instead of in the background'
complete -c sandvm -n "not __fish_seen_subcommand_from $subcommands" -s h -l help -d 'Show usage'

complete -c sandvm -n "__fish_seen_subcommand_from stop rm" -a '(__sandvm_names)' -d 'Sandbox instance'
