#!/bin/sh

# Return the context used with Kubectl, along with TMUX color highlights
# 

main()
{
  if ! type kubectl >/dev/null 2>&1; then
      echo "! kubectl doesn't exist !"
      exit 0
  fi

  if ! context="$(kubectl config current-context 2>/dev/null)"; then
      echo "❄ None"
      exit 0
  fi

  CTX=$(kubectl config current-context)

  if [[ $CTX == *"production"* ]]; then
    echo "❄ Prod"
  elif [[ $CTX == *"staging"* ]]; then
    echo "❄ Staging"
  else
    echo "❄ $CTX"
  fi
}

main
