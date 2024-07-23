#!/bin/bash
##### Set scenarios

## Scenario
export SCENARIO=$1
## Concurrent requests
export CONCURRENT_REQUESTS=$2
## Model Name
export MODEL_NAME=$3

## Total requests
if [ $CONCURRENT_REQUESTS -eq 16 ] && [ "$SCENARIO" != "GC" ] ; then
    export MAX_REQUESTS=1008
elif [ $CONCURRENT_REQUESTS -ne 16 ] && [ "$SCENARIO" != "GC" ]; then
    export MAX_REQUESTS=1000
elif [ $CONCURRENT_REQUESTS -eq 16 ] && [ "$SCENARIO" = "GC" ]; then
    export MAX_REQUESTS=320
else
    export MAX_REQUESTS=300
fi

## Endpoint for inference engine.
export OPENAI_API_BASE="http://172.16.0.123:8010/v1"
export OPENAI_API_KEY="na"

## Define standard deviation for input/output tokens, try to stable them.
export STDDEV_INPUT_TOKENS=0
export STDDEV_OUTPUT_TOKENS=0

## TIMEOUT, maximum testing time.
export TIMEOUT=3600

case $SCENARIO in
    ## Scenario 1, intent recognition.
    ## Input  : 50
    ## Output : 10
    IR)
      export MEAN_INPUT_TOKENS=50
      export MEAN_OUTPUT_TOKENS=10
    ;;

    ## Scenario 2, Q&A.
    ## Input  : 50
    ## Output : 150
    QA)
      export MEAN_INPUT_TOKENS=50
      export MEAN_OUTPUT_TOKENS=150
    ;;

    ## Scenario 3, Text Summarization
    ## Input  : 1000
    ## Output : 250
    TS)
      export MEAN_INPUT_TOKENS=1000
      export MEAN_OUTPUT_TOKENS=250
    ;;

    ## Scenario 4, Content Generation
    ## Input  : 100
    ## Output : 1000
    GC)
      export MEAN_INPUT_TOKENS=100
      export MEAN_OUTPUT_TOKENS=1000
    ;;

    ## Scenario 5, RAG
    ## Input  : 6000, 20 chunks total and 300 tokens for each chunk.
    ## Output : 500
    RAG)
      export MEAN_INPUT_TOKENS=6000
      export MEAN_OUTPUT_TOKENS=500
    ;;
esac

## Start the GPU monitoring command
perf=result_outputs/${MODEL_NAME}_${SCENARIO}_$(date +"%Y-%m-%d_%H-%M-%S").perf
nohup nvidia-smi --query-gpu=timestamp,name,utilization.gpu,utilization.memory,memory.total,memory.used --format=csv -l 1 > $perf &
pid=$!

## Start the benchmark
python token_benchmark_ray.py --model $MODEL_NAME --mean-input-tokens $MEAN_INPUT_TOKENS --stddev-input-tokens $STDDEV_INPUT_TOKENS --mean-output-tokens $MEAN_OUTPUT_TOKENS --stddev-output-tokens $STDDEV_OUTPUT_TOKENS --max-num-completed-requests $MAX_REQUESTS --timeout $TIMEOUT --num-concurrent-requests $CONCURRENT_REQUESTS --results-dir "result_outputs" --llm-api openai --additional-sampling-params '{"temperature": 0.5, "frequency_penalty": 1, "presence_penalty": 1}' > /dev/null

## Kill the performance monitoring command
kill $pid

## Analyze the results
report=result_outputs/${MODEL_NAME}_${MEAN_INPUT_TOKENS}_${MEAN_OUTPUT_TOKENS}_summary.json

#### 平均输出 (Tokens)
output_tokens=$(cat $report |grep results_number_output_tokens_mean|awk -F ":" '{print $2}'|sed 's/,//g')

#### 标准差
stddev=$(cat $report |grep results_number_output_tokens_stddev|awk -F ":" '{print $2}'|sed 's/,//g')

#### 平均TTFT (ms)
ttft_mean=$(cat $report |grep results_ttft_s_mean|awk -F ":" '{print $2}'|sed 's/,//g')

#### P99 TTFT (ms)
ttft_p99=$(cat $report |grep results_ttft_s_quantiles_p99|awk -F ":" '{print $2}'|sed 's/,//g')

#### 平均 ITL (ms)
itl_mean=$(cat $report |grep results_inter_token_latency_s_mean|awk -F ":" '{print $2}'|sed 's/,//g')

#### P99 ITL (ms)
itl_p99=$(cat $report |grep results_inter_token_latency_s_quantiles_p99|awk -F ":" '{print $2}'|sed 's/,//g')

#### 平均端到端响应时间 (ms)
e2e_mean=$(cat $report |grep results_end_to_end_latency_s_mean|awk -F ":" '{print $2}'|sed 's/,//g')

#### P99端到端响应时间 (ms)
e2e_p99=$(cat $report |grep results_end_to_end_latency_s_quantiles_p99|awk -F ":" '{print $2}'|sed 's/,//g')

#### Throughput (Tokens/s)
tokens_sec=$(cat $report |grep results_mean_output_throughput_token_per_s|awk -F ":" '{print $2}'|sed 's/,//g')

#### Throughput (Requests/s)
requests_sec=$(cat $report |grep results_num_completed_requests_per_min|awk -F ":" '{print $2}'|sed 's/,//g'| awk '{print $1 / 60}')

#### Average GPU Util (%)
avg_gpu=$(cat $perf | grep -v timestamp | awk '{ if ($5 > 50) print $5}' | awk '{ sum += $1} END { if (NR > 0) print sum / NR }')

#### VRAM Used (MB)"
avg_mem=$(cat $perf | grep -v timestamp | awk '{ if ($5 > 50) print $11}' | awk '{ sum += $1} END { if (NR > 0) print sum / NR }')

## Convert seconds to microseconds and round to keep 2 digits
output_tokens_round=$(echo "scale=3; ($output_tokens)/1" | bc)
stddev_round=$(echo "scale=3; ($stddev)/1" | bc)
ttft_mean_ms=$(echo "scale=3; ($ttft_mean * 1000)/1" | bc)
ttft_p99_ms=$(echo "scale=3; ($ttft_p99 * 1000)/1" | bc)
itl_mean_ms=$(echo "scale=3; ($itl_mean * 1000)/1" | bc)
itl_p99_ms=$(echo "scale=3; ($itl_p99 * 1000)/1" | bc)
e2e_mean_ms=$(echo "scale=3; ($e2e_mean * 1000)/1" | bc)
e2e_p99_ms=$(echo "scale=3; ($e2e_p99 * 1000)/1" | bc)
tokens_sec_round=$(echo "scale=3; ($tokens_sec)/1" | bc)
requests_sec_round=$(echo "scale=3; ($requests_sec)/1" | bc)
avg_gpu_round=$(echo "scale=3; ($avg_gpu)/1" | bc)
avg_mem_round=$(echo "scale=3; ($avg_mem)/1" | bc)

## Output the analysis result
echo "$output_tokens_round $stddev_round $ttft_mean_ms $ttft_p99_ms $itl_mean_ms $itl_p99_ms $e2e_mean_ms $e2e_p99_ms $tokens_sec_round $requests_sec_round $avg_gpu_round $avg_mem_round"
