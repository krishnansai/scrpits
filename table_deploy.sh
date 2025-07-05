#!/usr/bin/env bash

SEP="+----------------------+--------------------------------+---------------------------+--------------------------------------------+----------+----------+----------+----------+"
HEADER="| NAMESPACE            | POD                            | INGRESS                   | ENDPOINT URL                               | CPU      | MEMORY   | XMS      | XMX      |"

# Output file
OUTPUT="data.csv"

# Write header to output file
{
  echo "$SEP"
  echo "$HEADER"
  echo "$SEP"
} > "$OUTPUT"

# Also print to console
echo "$SEP"
echo "$HEADER"
echo "$SEP"

# Loop all namespaces
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  # Get pods
  pods=$(kubectl get pods -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
  pod=$(echo "$pods" | head -n1)
  if [[ -z "$pod" ]]; then
    continue
  fi

  # CPU and Memory Requests
  cpu=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  memory=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null)
  [[ -z "$cpu" ]] && cpu="N/A"
  [[ -z "$memory" ]] && memory="N/A"

  # JVM flags
  java_args=$(kubectl exec -n "$ns" "$pod" -- ps -o args= -C java 2>/dev/null || true)
  if [[ -z "$java_args" ]]; then
    java_args=$(kubectl exec -n "$ns" "$pod" -- ps -ef 2>/dev/null | grep '[j]ava' | awk '{$1=$2=$3=$4=$5=""; print $0}')
  fi

  xms="N/A"
  xmx="N/A"
  if [[ -n "$java_args" ]]; then
    [[ "$java_args" =~ (-Xms[^[:space:]]+) ]] && xms="${BASH_REMATCH[1]}"
    [[ "$java_args" =~ (-Xmx[^[:space:]]+) ]] && xmx="${BASH_REMATCH[1]}"
  fi

  # Ingress names
  ingress_names=$(kubectl get ingress -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null)
  [[ -z "$ingress_names" ]] && ingress_names="(none)"

  # Build URLs
  urls="N/A"
  if [[ "$ingress_names" != "(none)" ]]; then
    urls=""
    for ing_name in $ingress_names; do
      hosts=$(kubectl get ingress "$ing_name" -n "$ns" -o jsonpath='{range .spec.rules[*]}{.host}{" "}{end}' 2>/dev/null)
      tls=$(kubectl get ingress "$ing_name" -n "$ns" -o jsonpath='{.spec.tls}' 2>/dev/null)
      scheme="http"
      if [[ -n "$tls" && "$tls" != "null" ]]; then
        scheme="https"
      fi
      for host in $hosts; do
        urls="$urls ${scheme}://${host}"
      done
    done
    [[ -z "$urls" ]] && urls="N/A"
  fi

  # Remove leading space in URLs
  urls=$(echo "$urls" | sed 's/^ *//')

  # Print to console
  printf "| %-20s | %-30s | %-25s | %-42s | %-8s | %-8s | %-8s | %-8s |\n" \
    "$ns" "$pod" "$ingress_names" "$urls" "$cpu" "$memory" "$xms" "$xmx"
  echo "$SEP"

  # Write to file
  {
    printf "| %-20s | %-30s | %-25s | %-42s | %-8s | %-8s | %-8s | %-8s |\n" \
      "$ns" "$pod" "$ingress_names" "$urls" "$cpu" "$memory" "$xms" "$xmx"
    echo "$SEP"
  } >> "$OUTPUT"
done
