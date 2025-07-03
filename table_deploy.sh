#!/usr/bin/env bash

# Table formatting parameters
SEP="+----------------------+--------------------------------+---------------------------+----------+----------+----------+----------+----------+"
HEADER="| NAMESPACE            | DEPLOYMENT                     | INGRESS                   | CPU      | MEMORY   | HEAP     | XMX      | XMS      |"

# Print header
echo "$SEP"
echo "$HEADER"
echo "$SEP"

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  deploys=$(kubectl get deploy -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
  ing=$(kubectl get ing -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null)
  if [[ -z "$ing" ]]; then
    ing="(none)"
  fi

  for deploy in $deploys; do
    kubectl get deploy "$deploy" -n "$ns" -o json | jq -r --arg ns "$ns" --arg deploy "$deploy" --arg ing "$ing" '
      .spec.template.spec.containers[] | [
        $ns,
        $deploy,
        $ing,
        (.resources.requests.cpu // "NA"),
        (.resources.requests.memory // "NA"),
        (
          if .env then
            (.env[] | select(.name=="JAVA_OPTS").value // "")
          else ""
          end
        )
      ] | @tsv' | while IFS=$'\t' read -r namespace deploy ing cpu memory java_opts; do
        heap="NA"
        xmx="NA"
        xms="NA"
        if [[ -n "$java_opts" ]]; then
          [[ "$java_opts" =~ (-Xmx[^[:space:]]+) ]] && xmx="${BASH_REMATCH[1]}"
          [[ "$java_opts" =~ (-Xms[^[:space:]]+) ]] && xms="${BASH_REMATCH[1]}"
          [[ "$java_opts" =~ (-X[Hh]eap[^[:space:]]+) ]] && heap="${BASH_REMATCH[1]}"
        fi

        printf "| %-20s | %-30s | %-25s | %-8s | %-8s | %-8s | %-8s | %-8s |\n" \
          "$namespace" "$deploy" "$ing" "$cpu" "$memory" "$heap" "$xmx" "$xms"
        echo "$SEP"
    done
  done
done
