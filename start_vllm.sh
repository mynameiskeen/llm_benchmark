#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 MODEL_NAME, MODEL_NAME is one of :
          glm-4-9b-chat-gptq-int4
          glm-4-9b-chat
          qwen2-7b-instruct-gptq-int4
          qwen2-7b-instruct-awq-int4"
  exit 1
fi

MODEL_NAME=$1

case $MODEL_NAME in
  glm-4-9b-chat-int4)
    MODEL_PATH="/data/Models/GLM-4/glm-4-9b-chat-int4/"
    GPU_MEM_RATIO="0.95"
    MODEL_LENGTH="16384"
    ;;
  glm-4-9b-chat)
    MODEL_PATH="/data/Models/GLM-4/glm-4-9b-chat/"
    GPU_MEM_RATIO="0.95"
    MODEL_LENGTH="16384"
    ;;
  qwen2-7b-instruct-gptq-int4)
    MODEL_PATH="/data/Models/Qwen2/Qwen2-7B-Instruct-GPTQ-Int4/"
    GPU_MEM_RATIO="0.95"
    MODEL_LENGTH="16384"
    ;;
  qwen2-7b-instruct-awq-int4)
    MODEL_PATH="/data/Models/Qwen2/Qwen2-7B-Instruct-AWQ/"
    GPU_MEM_RATIO="0.95"
    MODEL_LENGTH="16384"
    ;;
  *)
    echo "Invalid MODEL_NAME: $MODEL_NAME"
    exit 1
    ;;
esac

OUTPUT="$(date +"%Y-%m-%d_%H-%M-%S").${MODEL_NAME}.out"

# Start vllm in the backgroud.
export CUDA_LAUNCH_BLOCKING=1
nohup /data/miniconda3/envs/vllm/bin/python -m vllm.entrypoints.openai.api_server --model $MODEL_PATH --trust-remote-code --dtype auto --host 0.0.0.0 --port 8010 --max-model-len $MODEL_LENGTH --gpu-memory-utilization $GPU_MEM_RATIO --device cuda --served-model-name $MODEL_NAME --max-parallel-loading-workers 64 --enable-chunked-prefill --max-num-batched-tokens 8192 --max-num-seqs 256 > $OUTPUT 2>&1 &
echo $! > pid
