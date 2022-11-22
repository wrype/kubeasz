#!/bin/bash

function usage() {
    echo -e "\033[33mUsage:\033[0m middleware.sh <cluster> [ansible-playbook args]"
}

function logger() {
  TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
  case "$1" in
    debug)
      echo -e "$TIMESTAMP \033[36mDEBUG\033[0m $2"
      ;;
    info)
      echo -e "$TIMESTAMP \033[32mINFO\033[0m $2"
      ;;
    warn)
      echo -e "$TIMESTAMP \033[33mWARN\033[0m $2"
      ;;
    error)
      echo -e "$TIMESTAMP \033[31mERROR\033[0m $2"
      ;;
    *)
      ;;
  esac
}

function main() {
    BASE="/etc/kubeasz"
    [[ -d "$BASE" ]] || { logger error "invalid dir:$BASE, try: 'ezdown -D'"; exit 1; }
    cd "$BASE"

    # check bash shell
    readlink /proc/$$/exe|grep -q "bash" || { logger error "you should use bash shell only"; exit 1; }

    # check 'ansible' executable
    which ansible > /dev/null 2>&1 || { logger error "need 'ansible', try: 'pip install ansible'"; usage; exit 1; }

    [ "$#" -gt 0 ] || { usage >&2; exit 2; }

    PLAY_BOOK=middleware.yml
    CLUSTER=$1
    shift
    ARGS=$@
    COMMAND="ansible-playbook -i clusters/$CLUSTER/hosts -e @clusters/$CLUSTER/config.yml $ARGS playbooks/$PLAY_BOOK"
    ${COMMAND} || exit 1
}

main "$@" 
