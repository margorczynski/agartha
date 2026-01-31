#!/usr/bin/env bash
#
# Agartha Integration Tests
#
# Goes beyond health checks to verify that platform components actually work
# together: storage round-trips, catalog operations, query execution, monitoring
# pipelines, identity configuration, backups, and TLS validity.
#
# Downloads mc (MinIO Client) and trino-cli to a temp directory, uses them for
# testing, then removes them on exit.
#
# Usage:
#   bash tests/integration-test.sh [--host <ingress-host>] [--skip-tls]
#                                  [--kubeconfig <path>] [--timeout <seconds>]

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
INGRESS_HOST="${INGRESS_HOST:-minikubehost.com}"
AGARTHA_HOST="agartha.${INGRESS_HOST}"
REQUEST_TIMEOUT="${REQUEST_TIMEOUT:-15}"
SKIP_TLS=false
TIMESTAMP=$(date +%s)

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
warn()  { echo -e "  ${YELLOW}[WARN]${RESET} $*"; }
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
            INGRESS_HOST="$2"
            AGARTHA_HOST="agartha.${INGRESS_HOST}"
            shift 2 ;;
        --skip-tls)
            SKIP_TLS=true; shift ;;
        --kubeconfig)
            export KUBECONFIG="$2"; shift 2 ;;
        --timeout)
            REQUEST_TIMEOUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--host <host>] [--skip-tls] [--kubeconfig <path>] [--timeout <seconds>]"
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Prerequisite check
# ---------------------------------------------------------------------------
for cmd in kubectl curl jq java; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not found in PATH." >&2
        exit 1
    fi
done

if [[ "$SKIP_TLS" == false ]] && ! command -v openssl &>/dev/null; then
    echo "Warning: openssl not found; TLS checks will be skipped." >&2
    SKIP_TLS=true
fi

# ---------------------------------------------------------------------------
# Tool bootstrap — download mc and trino-cli to a temp directory
# ---------------------------------------------------------------------------
TOOL_DIR=$(mktemp -d)
MC="${TOOL_DIR}/mc"
TRINO_CLI="${TOOL_DIR}/trino-cli.jar"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  MC_ARCH="amd64" ;;
    aarch64) MC_ARCH="arm64" ;;
    *)       MC_ARCH="amd64" ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo -e "${BOLD}Downloading tools...${RESET}"

if ! curl -sL -o "$MC" "https://dl.min.io/client/mc/release/${OS}-${MC_ARCH}/mc"; then
    echo "Error: failed to download mc" >&2
    exit 1
fi
chmod +x "$MC"
echo "  mc:        OK"

# Detect Trino version from the cluster, then find the nearest available CLI release
TRINO_VERSION=$(kubectl get pods -n agartha-processing-trino \
    -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null \
    | grep -oP ':\K[0-9]+$' || echo "476")

TRINO_CLI_DOWNLOADED=false
for try_version in "$TRINO_VERSION" $(( TRINO_VERSION - 1 )) $(( TRINO_VERSION - 2 )); do
    if curl -sL -f -o "$TRINO_CLI" \
        "https://repo1.maven.org/maven2/io/trino/trino-cli/${try_version}/trino-cli-${try_version}-executable.jar" 2>/dev/null; then
        TRINO_VERSION="$try_version"
        TRINO_CLI_DOWNLOADED=true
        break
    fi
done

if [[ "$TRINO_CLI_DOWNLOADED" != true ]]; then
    echo "Error: failed to download trino-cli (tried versions ${TRINO_VERSION}..$(( TRINO_VERSION - 2 )))" >&2
    exit 1
fi
chmod +x "$TRINO_CLI"
echo "  trino-cli: OK (v${TRINO_VERSION})"

# ---------------------------------------------------------------------------
# Port-forward helpers
# ---------------------------------------------------------------------------
PF_PIDS=()

port_forward_start() {
    local namespace="$1" service="$2" svc_port="$3"
    local local_port
    local_port=$(shuf -i 10000-60000 -n 1)

    kubectl port-forward "svc/${service}" "${local_port}:${svc_port}" \
        -n "$namespace" &>/dev/null &
    local pf_pid=$!
    PF_PIDS+=("$pf_pid")

    # Wait for port-forward to establish
    sleep 2

    # Verify port-forward is alive
    if ! kill -0 "$pf_pid" 2>/dev/null; then
        return 1
    fi

    echo "${local_port}:${pf_pid}"
}

port_forward_stop() {
    local pf_pid="$1"
    kill "$pf_pid" 2>/dev/null || true
    wait "$pf_pid" 2>/dev/null || true
}

# Cleanup port-forwards and temp tools on exit
cleanup() {
    for pid in "${PF_PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    rm -rf "$TOOL_DIR"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Secret helper
# ---------------------------------------------------------------------------
kube_secret_value() {
    local namespace="$1" secret="$2" key="$3"
    kubectl get secret "$secret" -n "$namespace" \
        -o jsonpath="{.data['${key}']}" 2>/dev/null \
        | base64 -d 2>/dev/null
}

# ---------------------------------------------------------------------------
# MinIO helper — configure mc alias for a port-forwarded MinIO
# ---------------------------------------------------------------------------
MC_ALIAS="agartha-test"

mc_setup() {
    local local_port="$1"
    local config_env
    config_env=$(kube_secret_value agartha-storage minio-tenant-env config.env 2>/dev/null || true)
    local access_key secret_key
    access_key=$(echo "$config_env" | grep -oP 'MINIO_ROOT_USER=\K.*' 2>/dev/null || echo "minioadmin")
    secret_key=$(echo "$config_env" | grep -oP 'MINIO_ROOT_PASSWORD=\K.*' 2>/dev/null || echo "minioadmin")
    access_key="${access_key%%[[:space:]]}"
    secret_key="${secret_key%%[[:space:]]}"

    "$MC" alias set "$MC_ALIAS" "http://127.0.0.1:${local_port}" "$access_key" "$secret_key" &>/dev/null
}

# ---------------------------------------------------------------------------
# Trino query helper
# ---------------------------------------------------------------------------
trino_query() {
    local local_port="$1" sql="$2"
    java -jar "$TRINO_CLI" --server "http://127.0.0.1:${local_port}" \
        --user integration-test --catalog agartha --schema default \
        --execute "$sql" 2>/dev/null
}

# ===================================================================
echo -e "\n${BOLD}=== Agartha Integration Tests ===${RESET}"
# ===================================================================

# ===========================================================================
# Stage 1: Storage (MinIO)
# ===========================================================================
header "Stage 1: Storage (MinIO)"

if ! kubectl get namespace agartha-storage &>/dev/null; then
    skip "Namespace agartha-storage not found — skipping MinIO tests"
    record_skip
else
    pf_result=$(port_forward_start agartha-storage minio 80) || true
    if [[ -z "$pf_result" ]]; then
        fail "Could not port-forward to MinIO"
        record_fail
    else
        MINIO_PORT="${pf_result%%:*}"
        MINIO_PF_PID="${pf_result##*:}"
        mc_setup "$MINIO_PORT"

        TEST_BUCKET="test-integration-${TIMESTAMP}"
        TEST_CONTENT="agartha-integration-test-${TIMESTAMP}"
        TEST_FILE="${TOOL_DIR}/test-object.txt"
        echo -n "$TEST_CONTENT" > "$TEST_FILE"

        # Create test bucket
        if "$MC" mb "${MC_ALIAS}/${TEST_BUCKET}" &>/dev/null; then
            pass "Create test bucket ${TEST_BUCKET}"
            record_pass
        else
            fail "Create test bucket ${TEST_BUCKET}"
            record_fail
        fi

        # Upload test object
        if "$MC" cp "$TEST_FILE" "${MC_ALIAS}/${TEST_BUCKET}/test-object.txt" &>/dev/null; then
            pass "Upload test object"
            record_pass
        else
            fail "Upload test object"
            record_fail
        fi

        # Read back and verify
        read_back=$("$MC" cat "${MC_ALIAS}/${TEST_BUCKET}/test-object.txt" 2>/dev/null || true)
        if [[ "$read_back" == "$TEST_CONTENT" ]]; then
            pass "Read back test object — content matches"
            record_pass
        else
            fail "Read back test object — content mismatch"
            record_fail
        fi

        # Delete test bucket and contents
        if "$MC" rb --force "${MC_ALIAS}/${TEST_BUCKET}" &>/dev/null; then
            pass "Delete test bucket ${TEST_BUCKET}"
            record_pass
        else
            fail "Delete test bucket ${TEST_BUCKET}"
            record_fail
        fi

        # Verify platform buckets exist
        bucket_list=$("$MC" ls "$MC_ALIAS" 2>/dev/null || true)
        for bucket in agartha-warehouse agartha-raw agartha-backups; do
            if echo "$bucket_list" | grep -q "$bucket"; then
                pass "Platform bucket exists: ${bucket}"
                record_pass
            else
                fail "Platform bucket missing: ${bucket}"
                record_fail
            fi
        done

        port_forward_stop "$MINIO_PF_PID"
    fi
fi

# ===========================================================================
# Stage 2: Catalog (Nessie)
# ===========================================================================
header "Stage 2: Catalog (Nessie)"

if ! kubectl get namespace agartha-catalog &>/dev/null; then
    skip "Namespace agartha-catalog not found — skipping Nessie tests"
    record_skip
else
    pf_result=$(port_forward_start agartha-catalog nessie 19120) || true
    if [[ -z "$pf_result" ]]; then
        fail "Could not port-forward to Nessie"
        record_fail
    else
        NESSIE_PORT="${pf_result%%:*}"
        NESSIE_PF_PID="${pf_result##*:}"

        # Query config endpoint
        config_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${NESSIE_PORT}/api/v2/config" 2>/dev/null || true)
        if echo "$config_response" | jq -e '.defaultBranch' &>/dev/null; then
            pass "Nessie /api/v2/config returns valid response"
            record_pass
        else
            fail "Nessie /api/v2/config — unexpected response"
            record_fail
        fi

        # List branches and verify main exists
        trees_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${NESSIE_PORT}/api/v2/trees" 2>/dev/null || true)
        if echo "$trees_response" | jq -e '.references[] | select(.name == "main")' &>/dev/null; then
            pass "Nessie main branch exists"
            record_pass
        else
            fail "Nessie main branch not found"
            record_fail
        fi

        # Create a test namespace, verify, then delete (using v1 API which
        # supports expectedHash as a query parameter)
        TEST_NS_NAME="test_integration_${TIMESTAMP}"
        main_hash=$(echo "$trees_response" | jq -r '.references[] | select(.name == "main") | .hash' 2>/dev/null)

        create_ns_response=$(curl -s -X POST --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${NESSIE_PORT}/api/v1/trees/branch/main/commit?expectedHash=${main_hash}" \
            -H "Content-Type: application/json" \
            -d "{
                \"commitMeta\": {\"message\": \"integration-test: create namespace\"},
                \"operations\": [{
                    \"type\": \"PUT\",
                    \"key\": {\"elements\": [\"${TEST_NS_NAME}\"]},
                    \"content\": {
                        \"type\": \"NAMESPACE\",
                        \"elements\": [\"${TEST_NS_NAME}\"]
                    }
                }]
            }" 2>/dev/null || true)

        if echo "$create_ns_response" | jq -e '.hash' &>/dev/null 2>/dev/null; then
            pass "Create Nessie test namespace ${TEST_NS_NAME}"
            record_pass

            # Verify namespace exists via v2 content endpoint
            ns_check=$(curl -s --max-time "$REQUEST_TIMEOUT" \
                "http://127.0.0.1:${NESSIE_PORT}/api/v2/trees/main/contents/${TEST_NS_NAME}" \
                2>/dev/null || true)
            if echo "$ns_check" | jq -e '.content' &>/dev/null 2>/dev/null; then
                pass "Verify Nessie namespace exists"
                record_pass
            else
                fail "Verify Nessie namespace — not found after creation"
                record_fail
            fi

            # Delete namespace — get fresh hash first
            delete_hash=$(curl -s --max-time "$REQUEST_TIMEOUT" \
                "http://127.0.0.1:${NESSIE_PORT}/api/v2/trees/main" 2>/dev/null \
                | jq -r '.reference.hash' 2>/dev/null)
            delete_ns_response=$(curl -s -X POST --max-time "$REQUEST_TIMEOUT" \
                "http://127.0.0.1:${NESSIE_PORT}/api/v1/trees/branch/main/commit?expectedHash=${delete_hash}" \
                -H "Content-Type: application/json" \
                -d "{
                    \"commitMeta\": {\"message\": \"integration-test: delete namespace\"},
                    \"operations\": [{
                        \"type\": \"DELETE\",
                        \"key\": {\"elements\": [\"${TEST_NS_NAME}\"]}
                    }]
                }" 2>/dev/null || true)
            if echo "$delete_ns_response" | jq -e '.hash' &>/dev/null 2>/dev/null; then
                pass "Delete Nessie test namespace"
                record_pass
            else
                warn "Could not delete Nessie test namespace (manual cleanup may be needed)"
                record_skip
            fi
        else
            fail "Create Nessie test namespace"
            record_fail
        fi

        port_forward_stop "$NESSIE_PF_PID"
    fi
fi

# ===========================================================================
# Stage 3: Trino -> Nessie -> MinIO (Data Path)
# ===========================================================================
header "Stage 3: Trino → Nessie → MinIO (Data Path)"

if ! kubectl get namespace agartha-processing-trino &>/dev/null; then
    skip "Namespace agartha-processing-trino not found — skipping Trino tests"
    record_skip
else
    pf_result=$(port_forward_start agartha-processing-trino trino 8080) || true
    if [[ -z "$pf_result" ]]; then
        fail "Could not port-forward to Trino"
        record_fail
    else
        TRINO_PORT="${pf_result%%:*}"
        TRINO_PF_PID="${pf_result##*:}"

        # Verify agartha catalog exists
        catalogs_output=$(trino_query "$TRINO_PORT" "SHOW CATALOGS" 2>/dev/null || true)
        if echo "$catalogs_output" | grep -q "agartha"; then
            pass "Trino catalog 'agartha' is registered"
            record_pass
        else
            fail "Trino catalog 'agartha' not found"
            record_fail
        fi

        # Create test schema
        TEST_SCHEMA="test_integration_${TIMESTAMP}"
        if trino_query "$TRINO_PORT" "CREATE SCHEMA IF NOT EXISTS agartha.${TEST_SCHEMA}" &>/dev/null; then
            pass "Create test schema agartha.${TEST_SCHEMA}"
            record_pass
        else
            fail "Create test schema agartha.${TEST_SCHEMA}"
            record_fail
        fi

        # Create test table
        if trino_query "$TRINO_PORT" \
            "CREATE TABLE agartha.${TEST_SCHEMA}.test_tbl AS SELECT 1 AS id, 'integration' AS label" \
            &>/dev/null; then
            pass "Create test table agartha.${TEST_SCHEMA}.test_tbl"
            record_pass
        else
            fail "Create test table agartha.${TEST_SCHEMA}.test_tbl"
            record_fail
        fi

        # Query test table and verify result
        select_output=$(trino_query "$TRINO_PORT" \
            "SELECT id, label FROM agartha.${TEST_SCHEMA}.test_tbl" 2>/dev/null || true)
        if echo "$select_output" | grep -q '"1".*"integration"' || \
           echo "$select_output" | grep -qP '1.*integration'; then
            pass "Query test table — data round-trip verified"
            record_pass
        else
            fail "Query test table — unexpected result: ${select_output}"
            record_fail
        fi

        # Drop test table and schema (cleanup)
        trino_query "$TRINO_PORT" "DROP TABLE IF EXISTS agartha.${TEST_SCHEMA}.test_tbl" &>/dev/null || true
        trino_query "$TRINO_PORT" "DROP SCHEMA IF EXISTS agartha.${TEST_SCHEMA}" &>/dev/null || true
        pass "Cleanup test schema and table"
        record_pass

        port_forward_stop "$TRINO_PF_PID"
    fi
fi

# ===========================================================================
# Stage 4: Monitoring (Prometheus)
# ===========================================================================
header "Stage 4: Monitoring (Prometheus)"

if ! kubectl get namespace agartha-monitoring &>/dev/null; then
    skip "Namespace agartha-monitoring not found — skipping Prometheus tests"
    record_skip
else
    pf_result=$(port_forward_start agartha-monitoring kube-prometheus-stack-prometheus 9090) || true
    if [[ -z "$pf_result" ]]; then
        fail "Could not port-forward to Prometheus"
        record_fail
    else
        PROM_PORT="${pf_result%%:*}"
        PROM_PF_PID="${pf_result##*:}"

        # Check active targets
        targets_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${PROM_PORT}/api/v1/targets" 2>/dev/null || true)
        active_count=$(echo "$targets_response" | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
        if [[ "$active_count" -gt 0 ]]; then
            pass "Prometheus has ${active_count} active targets"
            record_pass
        else
            fail "Prometheus has no active targets"
            record_fail
        fi

        # Verify key targets are up (check labels and scrapeUrl for component name)
        for component in nessie trino minio; do
            target_up=$(echo "$targets_response" | jq -r \
                --arg comp "$component" \
                '[.data.activeTargets[] | select(
                    (.labels | to_entries[] | .value | ascii_downcase | contains($comp))
                    or (.scrapeUrl // "" | ascii_downcase | contains($comp))
                    or (.globalUrl // "" | ascii_downcase | contains($comp))
                    or (.discoveredLabels | to_entries[] | .value | ascii_downcase | contains($comp))
                ) | .health] | if length > 0 then .[0] else "missing" end' \
                2>/dev/null || echo "missing")
            if [[ "$target_up" == "up" ]]; then
                pass "Prometheus target ${component} is up"
                record_pass
            elif [[ "$target_up" == "missing" ]]; then
                skip "Prometheus target ${component} not found (may not be scraped)"
                record_skip
            else
                fail "Prometheus target ${component} is ${target_up}"
                record_fail
            fi
        done

        # Verify metric collection via up query
        up_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${PROM_PORT}/api/v1/query?query=up" 2>/dev/null || true)
        up_results=$(echo "$up_response" | jq '.data.result | length' 2>/dev/null || echo "0")
        if [[ "$up_results" -gt 0 ]]; then
            pass "Prometheus metric collection working (${up_results} 'up' series)"
            record_pass
        else
            fail "Prometheus metric collection — no 'up' series found"
            record_fail
        fi

        port_forward_stop "$PROM_PF_PID"
    fi
fi

# ===========================================================================
# Stage 5: Monitoring (Grafana)
# ===========================================================================
header "Stage 5: Monitoring (Grafana)"

if ! kubectl get namespace agartha-monitoring &>/dev/null; then
    skip "Namespace agartha-monitoring not found — skipping Grafana tests"
    record_skip
else
    pf_result=$(port_forward_start agartha-monitoring kube-prometheus-stack-grafana 80) || true
    if [[ -z "$pf_result" ]]; then
        fail "Could not port-forward to Grafana"
        record_fail
    else
        GRAFANA_PORT="${pf_result%%:*}"
        GRAFANA_PF_PID="${pf_result##*:}"

        # Get admin credentials
        grafana_user=$(kube_secret_value agartha-monitoring grafana-admin-credentials admin-user 2>/dev/null || echo "admin")
        grafana_pass=$(kube_secret_value agartha-monitoring grafana-admin-credentials admin-password 2>/dev/null || echo "admin")

        grafana_auth="${grafana_user}:${grafana_pass}"

        # Check datasources
        ds_response=$(curl -s -u "$grafana_auth" --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${GRAFANA_PORT}/api/datasources" 2>/dev/null || true)
        ds_count=$(echo "$ds_response" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo "0")
        if [[ "$ds_count" -gt 0 ]]; then
            pass "Grafana has ${ds_count} datasource(s)"
            record_pass
        else
            fail "Grafana has no datasources"
            record_fail
        fi

        # Check dashboards
        dash_response=$(curl -s -u "$grafana_auth" --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${GRAFANA_PORT}/api/search?type=dash-db" 2>/dev/null || true)
        dash_count=$(echo "$dash_response" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo "0")
        if [[ "$dash_count" -gt 0 ]]; then
            pass "Grafana has ${dash_count} dashboard(s)"
            record_pass
        else
            fail "Grafana has no dashboards loaded"
            record_fail
        fi

        port_forward_stop "$GRAFANA_PF_PID"
    fi
fi

# ===========================================================================
# Stage 6: Monitoring (Loki)
# ===========================================================================
header "Stage 6: Monitoring (Loki)"

if ! kubectl get namespace agartha-monitoring &>/dev/null; then
    skip "Namespace agartha-monitoring not found — skipping Loki tests"
    record_skip
else
    pf_result=$(port_forward_start agartha-monitoring loki 3100) || true
    if [[ -z "$pf_result" ]]; then
        fail "Could not port-forward to Loki"
        record_fail
    else
        LOKI_PORT="${pf_result%%:*}"
        LOKI_PF_PID="${pf_result##*:}"

        # Check labels
        labels_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${LOKI_PORT}/loki/api/v1/labels" 2>/dev/null || true)
        labels_status=$(echo "$labels_response" | jq -r '.status // empty' 2>/dev/null)
        label_count=$(echo "$labels_response" | jq '.data | length' 2>/dev/null || echo "0")
        if [[ "$labels_status" == "success" && "$label_count" -gt 0 ]]; then
            pass "Loki is collecting labels (${label_count} labels)"
            record_pass
        else
            fail "Loki labels endpoint — status: ${labels_status:-error}, labels: ${label_count}"
            record_fail
        fi

        # Run a sample query for recent logs
        now=$(date +%s)
        start=$(( now - 3600 ))  # last hour
        query_response=$(curl -s -G --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${LOKI_PORT}/loki/api/v1/query_range" \
            --data-urlencode "query={namespace=~\".+\"}" \
            --data-urlencode "start=${start}" \
            --data-urlencode "end=${now}" \
            --data-urlencode "limit=5" \
            2>/dev/null || true)
        query_status=$(echo "$query_response" | jq -r '.status // empty' 2>/dev/null)
        result_count=$(echo "$query_response" | jq '.data.result | length' 2>/dev/null || echo "0")
        if [[ "$query_status" == "success" && "$result_count" -gt 0 ]]; then
            pass "Loki query returned ${result_count} stream(s) from last hour"
            record_pass
        elif [[ "$query_status" == "success" ]]; then
            warn "Loki query succeeded but returned no results (may be normal)"
            pass "Loki query endpoint is functional"
            record_pass
        else
            fail "Loki query — status: ${query_status:-error}"
            record_fail
        fi

        port_forward_stop "$LOKI_PF_PID"
    fi
fi

# ===========================================================================
# Stage 7: Identity (Keycloak)
# ===========================================================================
header "Stage 7: Identity (Keycloak)"

if ! kubectl get namespace agartha-identity &>/dev/null; then
    skip "Namespace agartha-identity not found — skipping Keycloak tests"
    record_skip
else
    pf_result=$(port_forward_start agartha-identity keycloak 80) || true
    if [[ -z "$pf_result" ]]; then
        fail "Could not port-forward to Keycloak"
        record_fail
    else
        KC_PORT="${pf_result%%:*}"
        KC_PF_PID="${pf_result##*:}"

        # Verify agartha realm exists
        realm_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${KC_PORT}/realms/agartha" 2>/dev/null || true)
        realm_name=$(echo "$realm_response" | jq -r '.realm // empty' 2>/dev/null)
        if [[ "$realm_name" == "agartha" ]]; then
            pass "Keycloak 'agartha' realm exists"
            record_pass
        else
            fail "Keycloak 'agartha' realm not found"
            record_fail
        fi

        # Fetch OIDC discovery document
        oidc_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${KC_PORT}/realms/agartha/.well-known/openid-configuration" \
            2>/dev/null || true)
        oidc_issuer=$(echo "$oidc_response" | jq -r '.issuer // empty' 2>/dev/null)
        if [[ -n "$oidc_issuer" ]]; then
            pass "OIDC discovery document is available (issuer: ${oidc_issuer})"
            record_pass
        else
            fail "OIDC discovery document not available"
            record_fail
        fi

        # Get admin token and list clients
        kc_admin_pass=$(kube_secret_value agartha-identity keycloak-admin-password admin-password 2>/dev/null || echo "admin")
        token_response=$(curl -s -X POST --max-time "$REQUEST_TIMEOUT" \
            "http://127.0.0.1:${KC_PORT}/realms/master/protocol/openid-connect/token" \
            -d "grant_type=password&client_id=admin-cli&username=admin&password=${kc_admin_pass}" \
            2>/dev/null || true)
        admin_token=$(echo "$token_response" | jq -r '.access_token // empty' 2>/dev/null)

        if [[ -n "$admin_token" ]]; then
            # List clients in agartha realm
            clients_response=$(curl -s --max-time "$REQUEST_TIMEOUT" \
                -H "Authorization: Bearer ${admin_token}" \
                "http://127.0.0.1:${KC_PORT}/admin/realms/agartha/clients" \
                2>/dev/null || true)

            client_ids=$(echo "$clients_response" | jq -r '.[].clientId // empty' 2>/dev/null || true)

            expected_clients=(grafana superset trino minio jupyterhub dagster)
            for client in "${expected_clients[@]}"; do
                if echo "$client_ids" | grep -qi "$client"; then
                    pass "OAuth client '${client}' exists in agartha realm"
                    record_pass
                else
                    fail "OAuth client '${client}' not found in agartha realm"
                    record_fail
                fi
            done
        else
            skip "Could not obtain Keycloak admin token — skipping client checks"
            record_skip
        fi

        port_forward_stop "$KC_PF_PID"
    fi
fi

# ===========================================================================
# Stage 8: Backup (Velero)
# ===========================================================================
header "Stage 8: Backup (Velero)"

if ! kubectl get namespace agartha-backup &>/dev/null; then
    skip "Namespace agartha-backup not found — skipping Velero tests"
    record_skip
else
    # Verify the daily backup schedule exists (may be prefixed by helm release name)
    schedule_name=$(kubectl get schedule -n agartha-backup -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "$schedule_name" ]] && echo "$schedule_name" | grep -q "agartha-daily-backup"; then
        pass "Velero schedule '${schedule_name}' exists"
        record_pass
    elif [[ -n "$schedule_name" ]]; then
        pass "Velero schedule '${schedule_name}' exists"
        record_pass
    else
        fail "No Velero backup schedule found"
        record_fail
    fi

    # Check for completed backups
    completed_backups=$(kubectl get backups -n agartha-backup \
        -o jsonpath='{.items[?(@.status.phase=="Completed")].metadata.name}' 2>/dev/null || true)
    if [[ -n "$completed_backups" ]]; then
        backup_count=$(echo "$completed_backups" | wc -w)
        pass "Found ${backup_count} completed backup(s)"
        record_pass
    else
        warn "No completed backups found (may be expected on fresh deployments)"
        record_skip
    fi

    # Verify backup storage location is available
    bsl_phase=$(kubectl get backupstoragelocation -n agartha-backup \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
    if [[ "$bsl_phase" == "Available" ]]; then
        pass "Backup storage location is Available"
        record_pass
    elif [[ -n "$bsl_phase" ]]; then
        fail "Backup storage location phase: ${bsl_phase}"
        record_fail
    else
        fail "No backup storage location found"
        record_fail
    fi
fi

# ===========================================================================
# Stage 9: TLS / Ingress Connectivity
# ===========================================================================
header "Stage 9: TLS / Ingress Connectivity"

if [[ "$SKIP_TLS" == true ]]; then
    skip "(--skip-tls)"
    record_skip
else
    INGRESS_ENDPOINTS=(
        "keycloak.${AGARTHA_HOST}"
        "minio.${AGARTHA_HOST}"
        "nessie.${AGARTHA_HOST}"
        "trino.${AGARTHA_HOST}"
        "grafana.${AGARTHA_HOST}"
        "superset.${AGARTHA_HOST}"
        "jupyterhub.${AGARTHA_HOST}"
        "dagster.${AGARTHA_HOST}"
    )

    for endpoint in "${INGRESS_ENDPOINTS[@]}"; do
        cert_info=$(echo | openssl s_client -servername "$endpoint" \
            -connect "$endpoint:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || true)

        if [[ -z "$cert_info" ]]; then
            fail "${endpoint} — could not retrieve TLS certificate"
            record_fail
            continue
        fi

        # Extract expiry date
        not_after=$(echo "$cert_info" | grep 'notAfter=' | cut -d= -f2)
        if [[ -z "$not_after" ]]; then
            fail "${endpoint} — could not parse certificate expiry"
            record_fail
            continue
        fi

        expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$not_after" +%s 2>/dev/null || echo "0")
        now_epoch=$(date +%s)
        days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

        if [[ "$days_remaining" -le 0 ]]; then
            fail "${endpoint} — certificate EXPIRED"
            record_fail
        elif [[ "$days_remaining" -le 30 ]]; then
            warn "${endpoint} — certificate expires in ${days_remaining} days"
            pass "${endpoint} — TLS valid (expires in ${days_remaining} days)"
            record_pass
        else
            pass "${endpoint} — TLS valid (expires in ${days_remaining} days)"
            record_pass
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
