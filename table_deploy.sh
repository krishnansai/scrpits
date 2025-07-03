#!/usr/bin/env bash

# Table headers
SEP="+----------------------+--------------------------------+---------------------------+--------------------------------------------+----------+----------+----------+----------+"
HEADER="| NAMESPACE            | POD                            | INGRESS                   | ENDPOINT                                   | CPU      | MEMORY   | XMS      | XMX      |"

echo "$SEP"
echo "$HEADER"
echo "$SEP"

# Loop through namespaces
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  # Get all pods in namespace
  pods=$(kubectl get pods -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
  # Take the first pod only
  pod=$(echo "$pods" | head -n1)
  if [[ -z "$pod" ]]; then
    continue
  fi

  # Get CPU and Memory Requests from the pod spec
  cpu=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
  memory=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.requests.memory}')
  [[ -z "$cpu" ]] && cpu="NA"
  [[ -z "$memory" ]] && memory="NA"

  # Get JVM flags from the running java process
  java_args=$(kubectl exec -n "$ns" "$pod" -- ps -o args= -C java 2>/dev/null)
  if [[ -z "$java_args" ]]; then
    java_args=$(kubectl exec -n "$ns" "$pod" -- ps -ef | grep '[j]ava' | awk '{$1=$2=$3=$4=$5=""; print $0}')
  fi

  xms="NA"
  xmx="NA"
  if [[ -n "$java_args" ]]; then
    [[ "$java_args" =~ (-Xms[^[:space:]]+) ]] && xms="${BASH_REMATCH[1]}"
    [[ "$java_args" =~ (-Xmx[^[:space:]]+) ]] && xmx="${BASH_REMATCH[1]}"
  fi

  # Get ingress name(s)
  ing=$(kubectl get ingress -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null)
  [[ -z "$ing" ]] && ing="(none)"

  # Get ingress endpoint(s)
  endpoint=$(kubectl get ingress -n "$ns" -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].hostname}{.status.loadBalancer.ingress[*].ip}{" "}{end}' 2>/dev/null)
  [[ -z "$endpoint" ]] && endpoint="(none)"

  printf "| %-20s | %-30s | %-25s | %-42s | %-8s | %-8s | %-8s | %-8s |\n" \
    "$ns" "$pod" "$ing" "$endpoint" "$cpu" "$memory" "$xms" "$xmx"
  echo "$SEP"
done
