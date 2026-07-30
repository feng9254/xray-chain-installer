#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
set -Eeuo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install.sh
source "${ROOT_DIR}/install.sh"

TEST_TMP_BASE='/var/tmp'
[[ -d "$TEST_TMP_BASE" ]] || TEST_TMP_BASE='/tmp'
TEST_DIR="$(mktemp -d "${TEST_TMP_BASE}/xray-chain-rollback-test.XXXXXXXX")"
cleanup_rollback_test() {
  if [[ ( "$TEST_DIR" == /var/tmp/xray-chain-rollback-test.* \
    || "$TEST_DIR" == /tmp/xray-chain-rollback-test.* ) && -d "$TEST_DIR" ]]; then
    rm -rf -- "$TEST_DIR"
  fi
}
trap cleanup_rollback_test EXIT

write_value() {
  local file="$1" value="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$value" >"$file"
}

assert_value() {
  local file="$1" expected="$2" actual
  [[ -f "$file" ]] || {
    printf '回滚测试缺少文件：%s\n' "$file" >&2
    return 1
  }
  actual="$(<"$file")"
  [[ "$actual" == "$expected" ]] || {
    printf '回滚内容不一致：%s（期望 %s，实际 %s）\n' \
      "$file" "$expected" "$actual" >&2
    return 1
  }
}

run_failure_case() (
  local case_name="$1" fail_point="$2" original_enabled="$3" original_active="$4"
  local case_dir="${TEST_DIR}/${case_name}" work_dir="${TEST_DIR}/${case_name}/work"
  local failed_status path

  BIN_DIR="${case_dir}/installed/bin"
  XRAY_BIN="${BIN_DIR}/xray"
  ASSET_DIR="${case_dir}/installed/assets"
  CONFIG_DIR="${case_dir}/installed/config"
  CONFIG_FILE="${CONFIG_DIR}/config.json"
  STATE_FILE="${CONFIG_DIR}/state.json"
  DATA_DIR="${case_dir}/installed/data"
  BACKUP_DIR="${DATA_DIR}/backups"
  SERVICE_FILE="${case_dir}/installed/xray-chain.service"
  MANAGER_BIN="${case_dir}/installed/puppyip"
  LEGACY_MANAGER_BIN="${case_dir}/installed/xray-chain"
  RUNTIME_GROUP="$(id -gn)"
  SERVICE_ENABLED_FILE="${case_dir}/service-enabled"
  SERVICE_ACTIVE_FILE="${case_dir}/service-active"
  FAILURE_MARKER="${case_dir}/failure-triggered"
  RESTART_MARKER="${case_dir}/deploy-restarted"

  mkdir -p "$BIN_DIR" "$ASSET_DIR" "$CONFIG_DIR" "$BACKUP_DIR" \
    "$(dirname "$SERVICE_FILE")" "$(dirname "$MANAGER_BIN")" "${work_dir}/xray"

  write_value "$XRAY_BIN" 'old-xray'
  write_value "${ASSET_DIR}/geoip.dat" 'old-geoip'
  write_value "${ASSET_DIR}/geosite.dat" 'old-geosite'
  write_value "$CONFIG_FILE" 'old-config'
  write_value "$STATE_FILE" 'old-state'
  write_value "$SERVICE_FILE" 'old-service'
  write_value "$MANAGER_BIN" 'old-manager'
  write_value "$LEGACY_MANAGER_BIN" 'old-legacy-manager'
  write_value "$SERVICE_ENABLED_FILE" "$original_enabled"
  write_value "$SERVICE_ACTIVE_FILE" "$original_active"

  write_value "${work_dir}/xray/xray" 'new-xray'
  write_value "${work_dir}/xray/geoip.dat" 'new-geoip'
  write_value "${work_dir}/xray/geosite.dat" 'new-geosite'
  write_value "${work_dir}/candidate-config.json" 'new-config'
  write_value "${work_dir}/candidate-state.json" 'new-state'
  write_value "${work_dir}/xray-chain.service" 'new-service'
  write_value "${work_dir}/manager" 'new-manager'

  should_fail_once() {
    local point="$1"
    [[ "$fail_point" == "$point" && ! -e "$FAILURE_MARKER" ]] || return 1
    : >"$FAILURE_MARKER"
    return 0
  }

  backup_copy_if_present() {
    local source="$1" destination="$2"
    if [[ "$fail_point" == 'backup-state' && "$source" == "$STATE_FILE" ]]; then
      return 1
    fi
    if [[ -f "$source" ]]; then
      cp -a -- "$source" "$destination"
    fi
  }

  atomic_install() {
    local source="$1" destination="$2"
    if [[ "$destination" == "$STATE_FILE" ]] && should_fail_once 'state-install'; then
      return 1
    fi
    if [[ "$destination" == "$LEGACY_MANAGER_BIN" ]] \
      && should_fail_once 'legacy-manager-install'; then
      return 1
    fi
    cp -- "$source" "$destination"
  }

  systemctl() {
    local command="${1:-}"
    case "$command" in
      is-enabled)
        [[ "$(<"$SERVICE_ENABLED_FILE")" == 'yes' ]]
        ;;
      is-active)
        if [[ -e "$RESTART_MARKER" ]] && should_fail_once 'active-check'; then
          return 1
        fi
        [[ "$(<"$SERVICE_ACTIVE_FILE")" == 'yes' ]]
        ;;
      daemon-reload)
        return 0
        ;;
      enable)
        write_value "$SERVICE_ENABLED_FILE" 'yes'
        ;;
      disable)
        write_value "$SERVICE_ENABLED_FILE" 'no'
        if [[ "${2:-}" == '--now' ]]; then
          write_value "$SERVICE_ACTIVE_FILE" 'no'
        fi
        ;;
      restart)
        if should_fail_once 'restart'; then
          return 1
        fi
        : >"$RESTART_MARKER"
        write_value "$SERVICE_ACTIVE_FILE" 'yes'
        ;;
      *)
        printf '回滚测试遇到未知 systemctl 调用：%s\n' "$*" >&2
        return 1
        ;;
    esac
  }

  journalctl() { :; }
  sleep() { :; }
  cleanup_runtime_layout_created_this_run() { :; }
  commit_runtime_layout() { :; }

  set +e
  (deploy_full "$work_dir" yes) >/dev/null 2>&1
  failed_status=$?
  set -e
  [[ "$failed_status" -ne 0 ]] || {
    printf '预期部署失败但实际成功：%s\n' "$case_name" >&2
    return 1
  }

  assert_value "$XRAY_BIN" 'old-xray'
  assert_value "${ASSET_DIR}/geoip.dat" 'old-geoip'
  assert_value "${ASSET_DIR}/geosite.dat" 'old-geosite'
  assert_value "$CONFIG_FILE" 'old-config'
  assert_value "$STATE_FILE" 'old-state'
  assert_value "$SERVICE_FILE" 'old-service'
  assert_value "$MANAGER_BIN" 'old-manager'
  assert_value "$LEGACY_MANAGER_BIN" 'old-legacy-manager'
  assert_value "$SERVICE_ENABLED_FILE" "$original_enabled"
  assert_value "$SERVICE_ACTIVE_FILE" "$original_active"

  if [[ "$fail_point" == 'backup-state' ]]; then
    for path in "$BACKUP_DIR"/*; do
      [[ ! -e "$path" ]] || {
        printf '备份创建失败后残留了不完整备份：%s\n' "$path" >&2
        return 1
      }
    done
  fi
)

run_failure_case backup_failure backup-state yes yes
run_failure_case middle_file_failure state-install yes yes
run_failure_case manager_failure legacy-manager-install no no
run_failure_case restart_failure restart yes yes
run_failure_case healthcheck_failure active-check no no

printf '事务回滚检查通过。\n'
