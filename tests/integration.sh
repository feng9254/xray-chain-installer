#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install.sh
source "${ROOT_DIR}/install.sh"

for command_name in cmp curl jq sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf '缺少测试依赖：%s\n' "$command_name" >&2
    exit 1
  }
done

extract_test_zip() {
  local archive="$1" destination="$2"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$archive" -d "$destination"
    return
  fi
  command -v python3 >/dev/null 2>&1 || {
    printf '缺少测试依赖：unzip 或 python3\n' >&2
    return 1
  }
  python3 - "$archive" "$destination" <<'PY'
import pathlib
import sys
import zipfile

archive, destination = sys.argv[1:]
with zipfile.ZipFile(archive) as bundle:
    for member in bundle.infolist():
        path = pathlib.PurePosixPath(member.filename)
        if path.is_absolute() or ".." in path.parts or "\\" in member.filename:
            raise SystemExit(f"unsafe zip member: {member.filename}")
    bundle.extractall(destination)
PY
}

TEST_TMP_BASE='/var/tmp'
[[ -d "$TEST_TMP_BASE" ]] || TEST_TMP_BASE='/tmp'
TEST_DIR="$(mktemp -d "${TEST_TMP_BASE}/xray-chain-test.XXXXXXXX")"
cleanup_test() {
  if [[ ( "$TEST_DIR" == /var/tmp/xray-chain-test.* || "$TEST_DIR" == /tmp/xray-chain-test.* ) && -d "$TEST_DIR" ]]; then
    rm -rf -- "$TEST_DIR"
  fi
}
trap cleanup_test EXIT

if [[ -n "${XRAY_TEST_BIN:-}" ]]; then
  TEST_XRAY="$XRAY_TEST_BIN"
  TEST_ASSETS="${XRAY_TEST_ASSET_DIR:-$(dirname "$XRAY_TEST_BIN")}"
  TEST_VERSION_OUTPUT="$($TEST_XRAY version)"
  TEST_VERSION_FIRST_LINE="${TEST_VERSION_OUTPUT%%$'\n'*}"
  TEST_VERSION="$(awk '{print $2}' <<<"$TEST_VERSION_FIRST_LINE")"
else
  case "$(uname -m)" in
    x86_64|amd64) TEST_ARCH='64' ;;
    aarch64|arm64) TEST_ARCH='arm64-v8a' ;;
    armv7l|armv7) TEST_ARCH='arm32-v7a' ;;
    *) printf '不支持测试架构：%s\n' "$(uname -m)" >&2; exit 1 ;;
  esac
  TEST_TAG="${XRAY_TEST_VERSION:-$DEFAULT_XRAY_VERSION}"
  TEST_ASSET="Xray-linux-${TEST_ARCH}.zip"
  TEST_URL="https://github.com/XTLS/Xray-core/releases/download/${TEST_TAG}/${TEST_ASSET}"
  curl -fL --retry 3 -o "${TEST_DIR}/${TEST_ASSET}" "$TEST_URL"
  curl -fL --retry 3 -o "${TEST_DIR}/${TEST_ASSET}.dgst" "${TEST_URL}.dgst"
  TEST_EXPECTED="$(awk -F'= *' '/^SHA2-256=/{print $2; exit}' "${TEST_DIR}/${TEST_ASSET}.dgst" | tr -d '[:space:]')"
  TEST_ACTUAL="$(sha256sum "${TEST_DIR}/${TEST_ASSET}" | awk '{print $1}')"
  [[ "${TEST_ACTUAL,,}" == "${TEST_EXPECTED,,}" ]] || {
    printf '测试用 Xray SHA-256 不匹配。\n' >&2
    exit 1
  }
  mkdir -p "${TEST_DIR}/xray"
  extract_test_zip "${TEST_DIR}/${TEST_ASSET}" "${TEST_DIR}/xray"
  TEST_XRAY="${TEST_DIR}/xray/xray"
  TEST_ASSETS="${TEST_DIR}/xray"
  TEST_VERSION="$TEST_TAG"
fi
chmod +x "$TEST_XRAY"

prepare_manager_copy "${TEST_DIR}/manager"
cmp -s "${ROOT_DIR}/install.sh" "${TEST_DIR}/manager"

TEST_KEY_OUTPUT="$($TEST_XRAY x25519 2>&1)"
PRIVATE_KEY="$(awk -F': *' 'tolower($1) ~ /^private/ {print $2; exit}' <<<"$TEST_KEY_OUTPUT" | tr -d '[:space:]')"
PUBLIC_KEY="$(awk -F': *' 'tolower($1) ~ /^(password|public)/ {print $2; exit}' <<<"$TEST_KEY_OUTPUT" | tr -d '[:space:]')"
[[ -n "$PRIVATE_KEY" && -n "$PUBLIC_KEY" ]]

MODEL_FILE="${TEST_DIR}/model.json"
SECRETS_FILE="${TEST_DIR}/secrets.json"
jq -n \
  --arg version "$TEST_VERSION" \
  --arg public_key "$PUBLIC_KEY" '
  {
    schema: 2,
    installedAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z",
    installerVersion: "fixture",
    xrayVersion: $version,
    serverAddress: "203.0.113.10",
    inboundPort: 443,
    realityTarget: "www.bing.com:443",
    serverName: "www.bing.com",
    realityPublicKey: $public_key,
    nextNodeNumber: 4,
    nodes: [
      {
        id: "node-1",
        number: 1,
        name: "PuppyIP-198.51.100.1",
        email: "node-1@puppyip.local",
        uuid: "3d107e9d-771a-41a8-88f3-94a9747a8f27",
        shortId: "0123456789abcdef",
        spiderX: "/1111111111111111",
        udpMode: "block",
        socksHost: "127.0.0.1",
        socksPort: 1080,
        socksUser: "fixture-user",
        exitIp: "198.51.100.1"
      },
      {
        id: "node-2",
        number: 2,
        name: "PuppyIP-198.51.100.2",
        email: "node-2@puppyip.local",
        uuid: "5c162020-e696-4d7c-a059-3ba41d9d5155",
        shortId: "fedcba9876543210",
        spiderX: "/2222222222222222",
        udpMode: "proxy",
        socksHost: "127.0.0.2",
        socksPort: 2080,
        socksUser: "",
        exitIp: "198.51.100.2"
      },
      {
        id: "node-3",
        number: 3,
        name: "PuppyIP-203.0.113.10",
        email: "node-3@puppyip.local",
        uuid: "7eced900-5bc5-493c-b253-252e699c9397",
        shortId: "0011223344556677",
        spiderX: "/5555555555555555",
        udpMode: "proxy",
        type: "direct",
        socksHost: "",
        socksPort: 0,
        socksUser: "",
        exitIp: "203.0.113.10"
      }
    ]
  }
' >"$MODEL_FILE"
jq -n --arg pass 'p:a"ss\word' '{"node-1": $pass, "node-2": ""}' >"$SECRETS_FILE"
chmod 0600 "$MODEL_FILE" "$SECRETS_FILE"
validate_model "$MODEL_FILE"
validate_model_secrets

GENERATED_STATE="${TEST_DIR}/generated-state.json"
GENERATED_CONFIG="${TEST_DIR}/generated-config.json"
render_state "$GENERATED_STATE" "$TEST_VERSION"
render_config "$GENERATED_CONFIG" "$TEST_DIR" "$GENERATED_STATE" "$SECRETS_FILE"
XRAY_LOCATION_ASSET="$TEST_ASSETS" "$TEST_XRAY" run -test -c "$GENERATED_CONFIG"

jq -e '.schema == 2 and (.nodes | length == 3) and .nextNodeNumber == 4' "$GENERATED_STATE" >/dev/null
jq -e '.inbounds[0].settings.clients | length == 3' "$GENERATED_CONFIG" >/dev/null
jq -e '.inbounds[0].streamSettings.realitySettings.shortIds | length == 3' "$GENERATED_CONFIG" >/dev/null
jq -e --arg secret 'p:a"ss\word' \
  '.outbounds[] | select(.tag == "socks-out-node-1") | .settings.pass == $secret' \
  "$GENERATED_CONFIG" >/dev/null
jq -e \
  '.outbounds[] | select(.tag == "socks-out-node-2") | (.settings | has("user") or has("pass")) | not' \
  "$GENERATED_CONFIG" >/dev/null
jq -e '
  .outbounds[]
  | select(.tag == "direct-out-node-3")
  | .protocol == "freedom" and .settings.domainStrategy == "AsIs"
' "$GENERATED_CONFIG" >/dev/null
jq -e 'has("node-3") | not' "$SECRETS_FILE" >/dev/null
jq -e '
  [.routing.rules[]
   | select(.user == ["node-1@puppyip.local"] and .outboundTag == "socks-out-node-1")]
  | length == 1
' "$GENERATED_CONFIG" >/dev/null
jq -e '
  [.routing.rules[]
   | select(.user == ["node-2@puppyip.local"] and .outboundTag == "socks-out-node-2")]
  | length == 1
' "$GENERATED_CONFIG" >/dev/null
jq -e '
  [.routing.rules[]
   | select(.user == ["node-3@puppyip.local"] and .outboundTag == "direct-out-node-3")]
  | length == 1
' "$GENERATED_CONFIG" >/dev/null
jq -e '
  [.routing.rules[]
   | select(.network == "udp" and .user == ["node-1@puppyip.local"] and .outboundTag == "blocked")]
  | length == 1
' "$GENERATED_CONFIG" >/dev/null
jq -e '
  [.routing.rules[]
   | select(.network == "udp" and .user == ["node-3@puppyip.local"] and .outboundTag == "blocked")]
  | length == 0
' "$GENERATED_CONFIG" >/dev/null
jq -e '
  .routing.rules[-1]
  | .inboundTag == ["vless-in"] and .outboundTag == "blocked"
' "$GENERATED_CONFIG" >/dev/null

STATE_FILE="$GENERATED_STATE"
LINK_ONE="$(build_share_link 1)"
LINK_TWO="$(build_share_link 2)"
LINK_THREE="$(build_share_link 3)"
[[ "$LINK_ONE" == vless://3d107e9d-771a-41a8-88f3-94a9747a8f27@203.0.113.10:443\?* ]]
[[ "$LINK_ONE" == *'spx=%2F1111111111111111'* ]]
[[ "$LINK_ONE" == *'#PuppyIP-198.51.100.1'* ]]
[[ "$LINK_TWO" == vless://5c162020-e696-4d7c-a059-3ba41d9d5155@203.0.113.10:443\?* ]]
[[ "$LINK_THREE" == vless://7eced900-5bc5-493c-b253-252e699c9397@203.0.113.10:443\?* ]]
[[ "$LINK_THREE" == *'#PuppyIP-203.0.113.10'* ]]
[[ "$LINK_ONE" != *'p:a'* && "$LINK_TWO" != *'p:a'* && "$LINK_THREE" != *'p:a'* ]]
NODE_LIST_OUTPUT="$(print_node_list_file "$STATE_FILE")"
[[ "$NODE_LIST_OUTPUT" == *'出口：VPS 本机直连 · 公网 IPv4：203.0.113.10'* ]]
DIRECT_CONNECTION_OUTPUT="$(show_connection 3)"
[[ "$DIRECT_CONNECTION_OUTPUT" == *'不经过 SOCKS5'* ]]
[[ "$DIRECT_CONNECTION_OUTPUT" == *'UDP：经 VPS 本机网络直接发送'* ]]

# Reloading a mixed direct/SOCKS installation keeps direct nodes passwordless
# and treats older schema-2 nodes without an explicit type as SOCKS.
CONFIG_FILE="$GENERATED_CONFIG"
ROUNDTRIP_WORK="${TEST_DIR}/mixed-roundtrip"
mkdir -p "$ROUNDTRIP_WORK"
load_model "$ROUNDTRIP_WORK" "$TEST_XRAY"
jq -e '
  (.nodes[] | select(.id == "node-1") | .type) == "socks"
  and (.nodes[] | select(.id == "node-2") | .type) == "socks"
  and (.nodes[] | select(.id == "node-3") | .type) == "direct"
' "$MODEL_FILE" >/dev/null
jq -e 'has("node-3") | not' "$SECRETS_FILE" >/dev/null

# Legacy schema 1 must migrate without changing the original UUID, short ID,
# inbound port, SOCKS endpoint, password, or REALITY key pair.
LEGACY_DIR="${TEST_DIR}/legacy"
mkdir -p "$LEGACY_DIR"
STATE_FILE="${LEGACY_DIR}/state.json"
CONFIG_FILE="${LEGACY_DIR}/config.json"
jq -n --arg public_key "$PUBLIC_KEY" '
  {
    schema: 1,
    installedAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-02T00:00:00Z",
    installerVersion: "0.1.0",
    xrayVersion: "v26.3.27",
    serverAddress: "203.0.113.20",
    inboundPort: 8443,
    uuid: "ed9e310c-e22b-4f22-9baf-6b6405e54255",
    realityTarget: "www.microsoft.com:443",
    serverName: "www.microsoft.com",
    publicKey: $public_key,
    shortId: "aabbccddeeff0011",
    udpMode: "block",
    nodeName: "PuppyIP-Chain",
    socksHost: "127.0.0.3",
    socksPort: 3080,
    socksUser: "legacy-user"
  }
' >"$STATE_FILE"
jq -n --arg private_key "$PRIVATE_KEY" --arg pass 'legacy-test-password' '
  {
    inbounds: [{
      tag: "vless-in",
      streamSettings: {realitySettings: {privateKey: $private_key}}
    }],
    outbounds: [{
      tag: "socks-out",
      protocol: "socks",
      settings: {
        address: "127.0.0.3",
        port: 3080,
        user: "legacy-user",
        pass: $pass
      }
    }]
  }
' >"$CONFIG_FILE"
MIGRATION_WORK="${LEGACY_DIR}/work"
mkdir -p "$MIGRATION_WORK"
load_model "$MIGRATION_WORK" "$TEST_XRAY"
jq -e '
  .schema == 2
  and .inboundPort == 8443
  and .realityTarget == "www.bing.com:443"
  and .nodes[0].uuid == "ed9e310c-e22b-4f22-9baf-6b6405e54255"
  and .nodes[0].shortId == "aabbccddeeff0011"
  and .nodes[0].socksHost == "127.0.0.3"
  and .nodes[0].socksPort == 3080
  and .nextNodeNumber == 2
' "$MODEL_FILE" >/dev/null
jq -e '."node-1" == "legacy-test-password"' "$SECRETS_FILE" >/dev/null
[[ "$PRIVATE_KEY" != "" ]]
MIGRATED_STATE="${LEGACY_DIR}/migrated-state.json"
MIGRATED_CONFIG="${LEGACY_DIR}/migrated-config.json"
render_state "$MIGRATED_STATE" "$TEST_VERSION"
render_config "$MIGRATED_CONFIG" "$MIGRATION_WORK" "$MIGRATED_STATE" "$SECRETS_FILE"
XRAY_LOCATION_ASSET="$TEST_ASSETS" "$TEST_XRAY" run -test -c "$MIGRATED_CONFIG"

# Node numbers are monotonic and one batch can add two independent exits.
MODEL_FILE="${TEST_DIR}/model-crud.json"
SECRETS_FILE="${TEST_DIR}/secrets-crud.json"
cp -- "$GENERATED_STATE" "$MODEL_FILE"
jq -n --arg pass 'fixture-password' '{"node-1": $pass, "node-2": ""}' >"$SECRETS_FILE"
remove_node_from_model node-1
[[ "$(jq -r '.nextNodeNumber' "$MODEL_FILE")" == '4' ]]
collect_socks_batch_settings() {
  SOCKS_BATCH_ENTRIES=(
    '127.0.0.4:4080:node-three-user:node-three-password'
    '127.0.0.5:5080:node-four-user:node-four-password'
  )
}
verify_socks_proxy() {
  case "$SOCKS_HOST" in
    127.0.0.4) SOCKS_EXIT_IP='198.51.100.3' ;;
    127.0.0.5) SOCKS_EXIT_IP='198.51.100.4' ;;
    *) return 1 ;;
  esac
}
IDENTITY_CALLS=0
generate_node_identity() {
  ((IDENTITY_CALLS += 1))
  if [[ "$IDENTITY_CALLS" == '1' ]]; then
    UUID='164086e5-204b-4ac7-8737-8a9005b4f629'
    SHORT_ID='1234567890abcdef'
    SPIDER_X='/3333333333333333'
  elif [[ "$IDENTITY_CALLS" == '2' ]]; then
    UUID='d6ed87fb-d5f1-4de5-8e65-a0950ec342be'
    SHORT_ID='abcdef1234567890'
    SPIDER_X='/4444444444444444'
  elif [[ "$IDENTITY_CALLS" == '3' ]]; then
    UUID='9d9e2b83-7a43-429e-a220-0fb30f8fd386'
    SHORT_ID='8899aabbccddeeff'
    SPIDER_X='/6666666666666666'
  else
    UUID='fc72f376-6b6d-46a3-ac37-890e2f6243c8'
    SHORT_ID='7766554433221100'
    SPIDER_X='/7777777777777777'
  fi
}
append_batch_nodes_to_model "$TEST_XRAY"
[[ "${NEW_NODE_IDS[*]}" == 'node-4 node-5' ]]
jq -e '
  .nextNodeNumber == 6
  and ([.nodes[].id] == ["node-2", "node-3", "node-4", "node-5"])
  and .nodes[2].name == "PuppyIP-198.51.100.3"
  and .nodes[3].name == "PuppyIP-198.51.100.4"
  and .nodes[2].udpMode == "proxy"
  and .nodes[3].udpMode == "proxy"
' "$MODEL_FILE" >/dev/null
jq -e '
  .["node-4"] == "node-three-password"
  and .["node-5"] == "node-four-password"
' "$SECRETS_FILE" >/dev/null

# Editing a SOCKS node can change only its UDP policy while preserving the
# endpoint, verified exit IP, credentials, and remark.
update_node_socks_in_model node-4 <<< $'\nn' >/dev/null 2>&1
[[ "$NODE_SETTINGS_CHANGED" == 'yes' ]]
jq -e '
  (.nodes[] | select(.id == "node-4")) as $node
  | $node.udpMode == "block"
    and $node.socksHost == "127.0.0.4"
    and $node.socksPort == 4080
    and $node.exitIp == "198.51.100.3"
    and $node.name == "PuppyIP-198.51.100.3"
' "$MODEL_FILE" >/dev/null
jq -e '."node-4" == "node-three-password"' "$SECRETS_FILE" >/dev/null
update_node_socks_in_model node-4 <<< $'\nn' >/dev/null 2>&1
[[ "$NODE_SETTINGS_CHANGED" == 'no' ]]
update_node_socks_in_model node-4 <<< $'\ny' >/dev/null 2>&1
[[ "$NODE_SETTINGS_CHANGED" == 'yes' ]]
jq -e '.nodes[] | select(.id == "node-4") | .udpMode == "proxy"' "$MODEL_FILE" >/dev/null

# Empty input creates one verified VPS-direct node instead of a SOCKS node.
collect_socks_batch_settings() {
  ADD_DIRECT_NODE='yes'
  SOCKS_BATCH_ENTRIES=()
}
verify_direct_outbound() { SOCKS_EXIT_IP='198.51.100.5'; }
append_batch_nodes_to_model "$TEST_XRAY"
[[ "${NEW_NODE_IDS[*]}" == 'node-6' ]]
jq -e '
  .nextNodeNumber == 7
  and .nodes[-1].id == "node-6"
  and .nodes[-1].type == "direct"
  and .nodes[-1].name == "PuppyIP-198.51.100.5"
  and .nodes[-1].socksHost == ""
  and .nodes[-1].socksPort == 0
  and .nodes[-1].udpMode == "proxy"
' "$MODEL_FILE" >/dev/null
jq -e 'has("node-6") | not' "$SECRETS_FILE" >/dev/null

# An operator can still explicitly block UDP for a newly added SOCKS node.
XRAY_CHAIN_UDP_MODE='block'
NODE_TYPE='socks'
SOCKS_HOST='127.0.0.6'
SOCKS_PORT='6080'
SOCKS_USER='node-seven-user'
SOCKS_PASS='node-seven-password'
SOCKS_EXIT_IP='198.51.100.6'
append_current_node_to_model "$TEST_XRAY"
unset XRAY_CHAIN_UDP_MODE
[[ "$SELECTED_NODE_ID" == 'node-7' ]]
jq -e '
  .nextNodeNumber == 8
  and .nodes[-1].id == "node-7"
  and .nodes[-1].udpMode == "block"
' "$MODEL_FILE" >/dev/null
jq -e '."node-7" == "node-seven-password"' "$SECRETS_FILE" >/dev/null

CRUD_STATE="${TEST_DIR}/crud-state.json"
CRUD_CONFIG="${TEST_DIR}/crud-config.json"
render_state "$CRUD_STATE" "$TEST_VERSION"
render_config "$CRUD_CONFIG" "$TEST_DIR" "$CRUD_STATE" "$SECRETS_FILE"
XRAY_LOCATION_ASSET="$TEST_ASSETS" "$TEST_XRAY" run -test -c "$CRUD_CONFIG"

# A mid-deployment write failure must exercise the real transaction path and
# restore the files that were already replaced.
DEPLOY_ROOT="${TEST_DIR}/deploy-failure"
mkdir -p "${DEPLOY_ROOT}/work/xray" "${DEPLOY_ROOT}/assets" "${DEPLOY_ROOT}/config" \
  "${DEPLOY_ROOT}/backups" "${DEPLOY_ROOT}/bin"
printf 'old-config' >"${DEPLOY_ROOT}/config/config.json"
printf 'old-state' >"${DEPLOY_ROOT}/config/state.json"
printf 'old-xray' >"${DEPLOY_ROOT}/bin/xray"
printf 'old-geoip' >"${DEPLOY_ROOT}/assets/geoip.dat"
printf 'old-geosite' >"${DEPLOY_ROOT}/assets/geosite.dat"
printf 'old-service' >"${DEPLOY_ROOT}/service"
printf 'old-manager' >"${DEPLOY_ROOT}/puppyip"
printf 'old-legacy-manager' >"${DEPLOY_ROOT}/xray-chain"
printf 'candidate-xray' >"${DEPLOY_ROOT}/work/xray/xray"
printf 'candidate-geoip' >"${DEPLOY_ROOT}/work/xray/geoip.dat"
printf 'candidate-geosite' >"${DEPLOY_ROOT}/work/xray/geosite.dat"
set +e
(
  BIN_DIR="${DEPLOY_ROOT}/bin"
  XRAY_BIN="${BIN_DIR}/xray"
  ASSET_DIR="${DEPLOY_ROOT}/assets"
  CONFIG_DIR="${DEPLOY_ROOT}/config"
  CONFIG_FILE="${CONFIG_DIR}/config.json"
  STATE_FILE="${CONFIG_DIR}/state.json"
  DATA_DIR="${DEPLOY_ROOT}/data"
  BACKUP_DIR="${DEPLOY_ROOT}/backups"
  SERVICE_FILE="${DEPLOY_ROOT}/service"
  MANAGER_BIN="${DEPLOY_ROOT}/puppyip"
  LEGACY_MANAGER_BIN="${DEPLOY_ROOT}/xray-chain"
  RUNTIME_GROUP='root'
  ATOMIC_CALLS=0
  ensure_runtime_layout() { mkdir -p "$DATA_DIR" "$BACKUP_DIR"; }
  render_state() { cp -- "$MODEL_FILE" "$1"; }
  render_config() { printf 'candidate-config' >"$1"; }
  validate_config() { :; }
  assert_model_port_available() { :; }
  prepare_manager_copy() { printf 'candidate-manager' >"$1"; }
  systemctl() { return 0; }
  atomic_install() {
    local source="$1" destination="$2"
    ((ATOMIC_CALLS += 1))
    if [[ "$ATOMIC_CALLS" == '2' ]]; then
      return 1
    fi
    cp -- "$source" "$destination"
  }
  deploy_model_change "${DEPLOY_ROOT}/work" "$TEST_VERSION"
) >"${TEST_DIR}/deploy-failure.out" 2>"${TEST_DIR}/deploy-failure.err"
DEPLOY_FAILURE_STATUS=$?
set -e
[[ "$DEPLOY_FAILURE_STATUS" -ne 0 ]]
grep -Fqx 'old-config' "${DEPLOY_ROOT}/config/config.json"
grep -Fqx 'old-state' "${DEPLOY_ROOT}/config/state.json"

# Rollback restores every managed file, including both management commands.
TXN_ROOT="${TEST_DIR}/transaction"
BIN_DIR="${TXN_ROOT}/bin"
XRAY_BIN="${BIN_DIR}/xray"
ASSET_DIR="${TXN_ROOT}/assets"
CONFIG_DIR="${TXN_ROOT}/config"
CONFIG_FILE="${CONFIG_DIR}/config.json"
STATE_FILE="${CONFIG_DIR}/state.json"
SERVICE_FILE="${TXN_ROOT}/xray-chain.service"
MANAGER_BIN="${TXN_ROOT}/puppyip"
LEGACY_MANAGER_BIN="${TXN_ROOT}/xray-chain"
mkdir -p "$BIN_DIR" "$ASSET_DIR" "$CONFIG_DIR"
systemctl() { return 0; }

ROLLBACK_BACKUP="${TXN_ROOT}/backup-existing"
mkdir -p "$ROLLBACK_BACKUP"
for mapping in \
  'xray|xray' \
  'geoip.dat|geoip.dat' \
  'geosite.dat|geosite.dat' \
  'config.json|config.json' \
  'state.json|state.json' \
  'service|service' \
  'manager|manager' \
  'legacy-manager|legacy-manager'; do
  backup_name="${mapping%%|*}"
  printf 'old-%s' "$backup_name" >"${ROLLBACK_BACKUP}/${backup_name}"
done
printf 'yes' >"${ROLLBACK_BACKUP}/was-enabled"
printf 'yes' >"${ROLLBACK_BACKUP}/was-active"
printf 'new' >"$XRAY_BIN"
printf 'new' >"${ASSET_DIR}/geoip.dat"
printf 'new' >"${ASSET_DIR}/geosite.dat"
printf 'new' >"$CONFIG_FILE"
printf 'new' >"$STATE_FILE"
printf 'new' >"$SERVICE_FILE"
printf 'new' >"$MANAGER_BIN"
printf 'new' >"$LEGACY_MANAGER_BIN"
rollback_backup "$ROLLBACK_BACKUP" 2>"${TEST_DIR}/rollback-existing.log"
grep -Fqx 'old-xray' "$XRAY_BIN"
grep -Fqx 'old-geoip.dat' "${ASSET_DIR}/geoip.dat"
grep -Fqx 'old-geosite.dat' "${ASSET_DIR}/geosite.dat"
grep -Fqx 'old-config.json' "$CONFIG_FILE"
grep -Fqx 'old-state.json' "$STATE_FILE"
grep -Fqx 'old-service' "$SERVICE_FILE"
grep -Fqx 'old-manager' "$MANAGER_BIN"
grep -Fqx 'old-legacy-manager' "$LEGACY_MANAGER_BIN"

FRESH_BACKUP="${TXN_ROOT}/backup-fresh"
mkdir -p "$FRESH_BACKUP"
printf 'no' >"${FRESH_BACKUP}/was-enabled"
printf 'no' >"${FRESH_BACKUP}/was-active"
rollback_backup "$FRESH_BACKUP" 2>"${TEST_DIR}/rollback-fresh.log"
for managed_file in \
  "$XRAY_BIN" "${ASSET_DIR}/geoip.dat" "${ASSET_DIR}/geosite.dat" \
  "$CONFIG_FILE" "$STATE_FILE" "$SERVICE_FILE" "$MANAGER_BIN" "$LEGACY_MANAGER_BIN"; do
  [[ ! -e "$managed_file" ]]
done

printf '集成检查通过：%s\n' "$TEST_VERSION"
