#!/usr/bin/env bash
#
# Agartha Post-Deploy Smoke Test
#
# Verifies platform health after deployment by checking namespace existence,
# pod readiness, component health endpoints, and ingress resources.
#
# Usage:
#   bash tests/smoke-test.sh [--host <ingress-host>] [--skip-ingress]
#                            [--kubeconfig <path>] [--timeout <seconds>]

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
INGRESS_HOST="${INGRESS_HOST:-minikubehost.com}"
POD_TIMEOUT="${POD_TIMEOUT:-20}"
SKIP_INGRESS=false

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

pass()  { echo -e "  ${GREEN}[PASS]${RESET} $*"; }
fail()  { echo -e "  ${RED}[FAIL]${RESET} $*"; }
skip()  { echo -e "  ${YELLOW}[SKIP]${RESET} $*"; }
header(){ echo -e "\n${BOLD}${CYAN}--- $* ---${RESET}"; }

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASSED=0
FAILED=0
SKIPPED=0

record_pass()  { PASSED=$(( PASSED + 1 )); }
record_fail()  { FAILED=$(( FAILED + 1 )); }
record_skip()  { SKIPPED=$(( SKIPPED + 1 )); }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            INGRESS_HOST="$2"; shift 2 ;;
        --skip-ingress)
            SKIP_INGRESS=true; shift ;;
        --kubeconfig)
            export KUBECONFIG="$2"; shift 2 ;;
        --timeout)
            POD_TIMEOUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--host <host>] [--skip-ingress] [--kubeconfig <path>] [--timeout <seconds>]"
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Prerequisite check
# ---------------------------------------------------------------------------
for cmd in kubectl curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not found in PATH." >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Namespaces
# ---------------------------------------------------------------------------
NAMESPACES=(
    agartha-identity
    agartha-storage
    agartha-catalog
    agartha-processing-spark
    agartha-processing-flink
    agartha-processing-trino
    agartha-notebooks
    agartha-bi
    agartha-orchestration
    agartha-monitoring
    agartha-backup
)

# ---------------------------------------------------------------------------
# Health check definitions
# Each entry: "ComponentName|Namespace|Service|Port|HealthPath"
# ---------------------------------------------------------------------------
HEALTH_CHECKS=(
    "Keycloak|agartha-identity|keycloak|80|/realms/master"
    "MinIO|agartha-storage|minio|80|/minio/health/live"
    "Nessie|agartha-catalog|nessie|19120|/api/v1/config"
    "Trino|agartha-processing-trino|trino|8080|/v1/status"
    "Grafana|agartha-monitoring|kube-prometheus-stack-grafana|80|/api/health"
    "Prometheus|agartha-monitoring|kube-prometheus-stack-prometheus|9090|/-/healthy"
    "Alertmanager|agartha-monitoring|alertmanager-operated|9093|/-/healthy"
    "Loki|agartha-monitoring|loki|3100|/ready"
    "Superset|agartha-bi|superset|8088|/health"
    "JupyterHub|agartha-notebooks|proxy-public|80|/hub/health"
    "Dagster|agartha-orchestration|dagster-dagster-webserver|80|/server_info"
)

# ---------------------------------------------------------------------------
# Ingress definitions
# Each entry: "Namespace|IngressName|ExpectedHost"
# ---------------------------------------------------------------------------
INGRESS_CHECKS=(
    "agartha-identity|keycloak|keycloak.agartha.${INGRESS_HOST}"
    "agartha-storage|minio|minio.agartha.${INGRESS_HOST}"
    "agartha-catalog|nessie|nessie.agartha.${INGRESS_HOST}"
    "agartha-processing-trino|trino|trino.agartha.${INGRESS_HOST}"
    "agartha-monitoring|grafana|grafana.agartha.${INGRESS_HOST}"
    "agartha-bi|superset|superset.agartha.${INGRESS_HOST}"
    "agartha-notebooks|jupyterhub|jupyterhub.agartha.${INGRESS_HOST}"
    "agartha-orchestration|dagster|dagster.agartha.${INGRESS_HOST}"
)

# ===================================================================
echo -e "\n${BOLD}=== Agartha Post-Deploy Smoke Test ===${RESET}"
# ===================================================================

# ---------------------------------------------------------------------------
# Stage 1: Namespace Verification
# ---------------------------------------------------------------------------
header "Stage 1: Namespaces"

for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &>/dev/null; then
        pass "$ns"
        record_pass
    else
        fail "$ns"
        record_fail
    fi
done

# ---------------------------------------------------------------------------
# Stage 2: Pod Readiness
# ---------------------------------------------------------------------------
header "Stage 2: Pod Readiness"

for ns in "${NAMESPACES[@]}"; do
    if ! kubectl get namespace "$ns" &>/dev/null; then
        skip "$ns (namespace does not exist)"
        record_skip
        continue
    fi

    # Exclude Completed (Succeeded) pods — these are finished Jobs and should not
    # be considered for readiness (they will never become Ready).
    all_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null)
    active_pods=$(echo "$all_pods" | awk '$3 != "Completed"' | grep -v '^$' || true)
    total_active=$(echo "$active_pods" | grep -c . || true)

    if [[ "$total_active" -eq 0 ]]; then
        skip "$ns (no active pods)"
        record_skip
        continue
    fi

    # Check readiness only for non-completed pods using a field selector
    if kubectl wait --for=condition=Ready pods --field-selector=status.phase!=Succeeded \
            --all -n "$ns" --timeout="${POD_TIMEOUT}s" &>/dev/null; then
        pass "$ns (${total_active}/${total_active} pods ready)"
        record_pass
    else
        ready_pods=$(echo "$active_pods" \
            | awk '$2 ~ /[0-9]+\/[0-9]+/ { split($2,a,"/"); if(a[1]==a[2]) c++ } END { print c+0 }')
        fail "$ns (${ready_pods}/${total_active} pods ready)"
        # Show which active pods are not ready
        echo "$active_pods" \
            | awk '$2 ~ /[0-9]+\/[0-9]+/ { split($2,a,"/"); if(a[1]!=a[2]) print "         " $1 " (" $3 ")" }'
        record_fail
    fi
done

# ---------------------------------------------------------------------------
# Stage 3: Component Health Checks
# ---------------------------------------------------------------------------
header "Stage 3: Health Checks"

check_health() {
    local name="$1" namespace="$2" service="$3" svc_port="$4" path="$5"

    if ! kubectl get namespace "$namespace" &>/dev/null; then
        skip "$name ($path) - namespace $namespace not found"
        record_skip
        return
    fi

    if ! kubectl get svc "$service" -n "$namespace" &>/dev/null; then
        skip "$name ($path) - service $service not found"
        record_skip
        return
    fi

    # Pick a random local port in the high range to avoid collisions
    local local_port
    local_port=$(shuf -i 10000-60000 -n 1)

    # Start port-forward in background
    kubectl port-forward "svc/${service}" "${local_port}:${svc_port}" -n "$namespace" &>/dev/null &
    local pf_pid=$!

    # Give port-forward a moment to establish
    sleep 2

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        "http://localhost:${local_port}${path}" 2>/dev/null || echo "000")

    # Clean up port-forward
    kill "$pf_pid" 2>/dev/null || true
    wait "$pf_pid" 2>/dev/null || true

    if [[ "$http_code" == "200" ]]; then
        pass "$name ($path)"
        record_pass
    else
        fail "$name ($path) - HTTP $http_code"
        record_fail
    fi
}

for entry in "${HEALTH_CHECKS[@]}"; do
    IFS='|' read -r name namespace service port path <<< "$entry"
    check_health "$name" "$namespace" "$service" "$port" "$path"
done

# ---------------------------------------------------------------------------
# Stage 4: Ingress Verification
# ---------------------------------------------------------------------------
header "Stage 4: Ingress"

if [[ "$SKIP_INGRESS" == true ]]; then
    skip "(--skip-ingress)"
    record_skip
else
    for entry in "${INGRESS_CHECKS[@]}"; do
        IFS='|' read -r namespace ingress_name expected_host <<< "$entry"

        if ! kubectl get namespace "$namespace" &>/dev/null; then
            skip "$expected_host - namespace $namespace not found"
            record_skip
            continue
        fi

        # Look for an ingress in the namespace whose rules match the expected host
        ingress_json=$(kubectl get ingress -n "$namespace" -o json 2>/dev/null)

        if echo "$ingress_json" | grep -q "\"host\":.*\"${expected_host}\"" 2>/dev/null; then
            # Check if ingress has an address assigned
            has_address=$(echo "$ingress_json" \
                | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    for rule in item.get('spec', {}).get('rules', []):
        if rule.get('host') == '${expected_host}':
            ingress_list = item.get('status', {}).get('loadBalancer', {}).get('ingress', [])
            if ingress_list:
                print('yes')
                sys.exit(0)
print('no')
" 2>/dev/null || echo "no")

            if [[ "$has_address" == "yes" ]]; then
                pass "$expected_host"
                record_pass
            else
                fail "$expected_host - no address assigned"
                record_fail
            fi
        else
            fail "$expected_host - ingress not found"
            record_fail
        fi
    done
fi

# ===================================================================
# Summary
# ===================================================================
TOTAL=$(( PASSED + FAILED + SKIPPED ))

echo -e "\n${BOLD}=== Summary ===${RESET}"
echo -e "  ${GREEN}Passed:${RESET}  $PASSED"
echo -e "  ${RED}Failed:${RESET}  $FAILED"
echo -e "  ${YELLOW}Skipped:${RESET} $SKIPPED"
echo -e "  Total:   $TOTAL"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
exit 0
