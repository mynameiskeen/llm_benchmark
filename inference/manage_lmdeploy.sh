#!/bin/bash

####################################################################################################
#
# This script is used to manage lmdeploy as an inference server, it starts, stops and gets status
# of lmdeploy instance.
# 
####################################################################################################

# set -x 

###########################################################################
# Define a function to output error messages with red color.
###########################################################################
echo_error () {
  RED='\033[0;31m'
  NC='\033[0m'
  echo -e "${RED}$1${NC}"
}

###########################################################################
# Define a function to output normal logs with green color.
###########################################################################
echo_log () {
  GREEN='\033[0;32m'
  NC='\033[0m'
  local _timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  echo -e "${GREEN}$_timestamp: $1${NC}"
}

###########################################################################
# Define a function to start the lmdeploy instance.
###########################################################################
start () {
  # Check if $MODEL_NAME exists
  if [ ! -z $MODEL_NAME ]; then
    case $MODEL_NAME in
      glm-4-9b-chat-int4)
        MODEL_PATH="/data/Models/GLM-4/glm-4-9b-chat-int4/"
        GPU_MEM_RATIO="0.9"
        MODEL_LENGTH="16384"
        ;;
      glm-4-9b-chat)
        MODEL_PATH="/data/Models/GLM-4/glm-4-9b-chat/"
        GPU_MEM_RATIO="0.9"
        MODEL_LENGTH="16384"
        ;;
      qwen2-7b-instruct-gptq-int4)
        MODEL_PATH="/data/Models/Qwen2/Qwen2-7B-Instruct-GPTQ-Int4/"
        GPU_MEM_RATIO="0.9"
        MODEL_LENGTH="16384"
        ;;
      qwen2-7b-instruct-awq-int4)
        MODEL_PATH="/data/Models/Qwen2/Qwen2-7B-Instruct-AWQ/"
        GPU_MEM_RATIO="0.9"
        MODEL_LENGTH="16384"
        ;;
      *)
        echo_error "Invalid model name: $MODEL_NAME"
        help
        exit 1
        ;;
    esac
  else
    echo_error "The action: \"$ACTION\" must specify a model name."
    help
    exit 1
  fi

  # Check if the MODEL_PATH exists
  if [ ! -d $MODEL_PATH ]
    then
      echo "Path $MODEL_PATH does not exist!"
      exit 1
  fi
  # If lmdeploy is running
  if status; then
    echo_error "A lmdeploy instance is already running with pid: $_pid, please check!"
    exit 1
  fi

  # Define lmdeploy output log file.
  OUTPUT="$(date +"%Y-%m-%d_%H-%M-%S").${MODEL_NAME}.out"
  if [ ! -d logs ]; then
    mkdir logs
  fi

  # Start lmdeploy in the backgroud.
  echo_log "Starting lmdeploy with model: $MODEL_NAME ..."
  nohup /data/miniconda3/envs/lmdeploy/bin/python /data/miniconda3/envs/lmdeploy/bin/lmdeploy serve api_server $MODEL_PATH --log-level INFO --model-name $MODEL_NAME --server-port 8010 --session-len $MODEL_LENGTH > logs/$OUTPUT 2>&1 &
  if [ $? -ne 0 ]; then
    echo_error "Starting lmdeploy failed, please check log file logs/${OUTPUT}."
    exit 1
  fi
  # Remove the file link first
  if [ -L server.out ]; then
    rm server.out
  fi
  # Re-link the current log file to server.out
  ln -s logs/$OUTPUT server.out
  echo_log "The lmdeploy instance started."
}

###########################################################################
# Define a function to check the lmdeploy instance status.
#   - Running, return 0
#   - Not running, return 1
###########################################################################
status () {
  # Get current lmdeploy instance pid.
  _pid=$(ps aux | grep lmdeploy | grep [a]pi_server |awk '{print $2}')

  # If $_pid exists, return 0 else return 1.
  if [ x"$_pid" != "x" ]; then
    return 0
  else
    return 1
  fi
}

###########################################################################
# Define a function to stop the lmdeploy instance.
###########################################################################
stop () {
  # If lmdeploy is not running
  if ! status; then
    echo_error "There's no lmdeploy instance running."
    exit 1
  else
    kill $_pid
    # After kill, checking the log for "shutdown complete" message.
    while true
    do
      _status=$(tail -10 server.out | grep "shutdown complete" |wc -l)
      if [ $_status -eq 0 ]; then
        echo_log "The lmdeploy instance is terminating ..."
        sleep 2
      else
        echo_log "The lmdeploy instance stopped successfully."
        break
      fi
    done
  fi
}

###########################################################################
# Define a function to print help information
###########################################################################
help () {
  echo "Usage: $0 <start/stop/status> <model name>
        MODEL_NAME is one of :
          glm-4-9b-chat-gptq-int4
          glm-4-9b-chat
          qwen2-7b-instruct-gptq-int4
          qwen2-7b-instruct-awq-int4"
}

###########################################################################
# Main body of the script
###########################################################################

# Check input parameters.
if [ "$#" -lt 1 ]; then
  echo_error "You must input at least 1 parameters."
  help
  exit 1
fi

ACTION=$1

MODEL_NAME=$2

case $ACTION in 
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    if status; then
      echo "The lmdeploy instance is running."
    else
      echo "No lmdeploy instance running."
    fi
    ;;
  *)
    echo_error "Invalid action: $ACTION"
    help
    exit 1
    ;;
esac
