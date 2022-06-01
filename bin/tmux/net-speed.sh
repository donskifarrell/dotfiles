#!/usr/bin/env bash

# Taken from https://github.com/xamut/tmux-network-bandwidth
# For some reason home-manager won't let any plugin unless it's part of tmuxPlugins
#

get_tmux_option() {
  local option_name="$1"
  local default_value="$2"
  local option_value="$(tmux show-option -gqv $option_name)"

  if [ -z "$option_value" ]; then
    echo -n "$default_value"
  else
    echo -n "$option_value"
  fi
}

set_tmux_option() {
  local option_name="$1"
  local option_value="$2"
  $(tmux set-option -gq $option_name "$option_value")
}

get_bandwidth_for_osx() {
  netstat -ibn | awk 'FNR > 1 {
    interfaces[$1 ":bytesReceived"] = $(NF-4);
    interfaces[$1 ":bytesSent"]     = $(NF-1);
  } END {
    for (itemKey in interfaces) {
      split(itemKey, keys, ":");
      interface = keys[1]
      dataKind = keys[2]
      sum[dataKind] += interfaces[itemKey]
    }

    print sum["bytesReceived"], sum["bytesSent"]
  }'
}

get_bandwidth_for_linux() {
  netstat -ie | awk '
    match($0, /RX([[:space:]]packets[[:space:]][[:digit:]]+)?[[:space:]]+bytes[:[:space:]]([[:digit:]]+)/, rx) { rx_sum+=rx[2]; }
    match($0, /TX([[:space:]]packets[[:space:]][[:digit:]]+)?[[:space:]]+bytes[:[:space:]]([[:digit:]]+)/, tx) { tx_sum+=tx[2]; }
    END { print rx_sum, tx_sum }
  '
}

get_bandwidth() {
  case $(uname -s) in
    Darwin)
      echo -n $(get_bandwidth_for_osx)
      return 0
      ;;
    Linux)
      echo -n $(get_bandwidth_for_linux)
      return 0
      ;;
    *)
      echo -n "0 0"
      return 1
      ;;
  esac
}

format_speed() {
  local padding=$(get_tmux_option "@tmux-network-bandwidth-padding" 5)
  numfmt --to=iec-i --suffix "B/s" --format "%f" --padding $padding $1
}

main() {
  local sleep_time=$(get_tmux_option "status-interval")
  local old_value=$(get_tmux_option "@network-bandwidth-previous-value")

  if [ -z "$old_value" ]; then
    $(set_tmux_option "@network-bandwidth-previous-value" "-")
    echo -n "Please wait..."
    return 0
  else
    local first_measure=( $(get_bandwidth) )
    sleep $sleep_time
    local second_measure=( $(get_bandwidth) )
    local download_speed=$(((${second_measure[0]} - ${first_measure[0]}) / $sleep_time))
    local upload_speed=$(((${second_measure[1]} - ${first_measure[1]}) / $sleep_time))
    $(set_tmux_option "@network-bandwidth-previous-value" "↓ $(format_speed $download_speed) • ↑ $(format_speed $upload_speed)")
  fi

  echo -n "$(get_tmux_option "@network-bandwidth-previous-value")"
}

main