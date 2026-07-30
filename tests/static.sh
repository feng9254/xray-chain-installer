#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/install.sh"

bash -n "$SCRIPT"
bash -n "${ROOT_DIR}/tests/integration.sh"
[[ ! -f "${ROOT_DIR}/tests/preflight.sh" ]] || bash -n "${ROOT_DIR}/tests/preflight.sh"

bash -c '
  set -Eeuo pipefail
  source "$1"

  valid_ipv4_or_domain "203.0.113.10"
  valid_ipv4_or_domain "proxy.example.com"
  ! valid_ipv4_or_domain "999.0.0.1"
  ! valid_ipv4_or_domain "203.0.113.10:1080"
  ! valid_ipv4_or_domain "-proxy.example.com"
  valid_domain_name "www.bing.com"
  ! valid_domain_name "bad..example.com"
  valid_port "443"
  ! valid_port "70000"

  parse_socks5_entry "203.0.113.10:1080:test-user:test-password"
  [[ "$SOCKS_HOST" == "203.0.113.10" ]]
  [[ "$SOCKS_PORT" == "1080" ]]
  [[ "$SOCKS_USER" == "test-user" ]]
  [[ "$SOCKS_PASS" == "test-password" ]]
  parse_socks5_entry "proxy.example.com:1080:test-user:part1:part2"
  [[ "$SOCKS_PASS" == "part1:part2" ]]
  parse_socks5_entry "203.0.113.10:1080"
  [[ -z "$SOCKS_USER" && -z "$SOCKS_PASS" ]]
  ! parse_socks5_entry "203.0.113.10:1080:user-only"
  ! parse_socks5_entry "203.0.113.10:70000:user:password"

  printf -v batch_input "%s\n%s" \
    "203.0.113.10:1080:user1:password1 198.51.100.20:2080:user2:part1:part2" \
    "proxy.example.com:3080"
  parse_socks5_batch_input "$batch_input"
  [[ "${#SOCKS_BATCH_ENTRIES[@]}" == "3" ]]
  [[ "${SOCKS_BATCH_ENTRIES[1]}" == "198.51.100.20:2080:user2:part1:part2" ]]
  printf -v batch_input "%s\n%s" \
    "203.0.113.10:1080:user1:password1" "invalid-entry"
  ! parse_socks5_batch_input "$batch_input"
  [[ "$SOCKS_BATCH_ERROR_INDEX" == "2" ]]

  new_temp_dir
  panel_fixture_dir="$LAST_TEMP_DIR"
  platform_fixture="$panel_fixture_dir/os-release"
  system_advice_output="$(show_supported_system_advice 2>&1)"
  [[ "$system_advice_output" == *"请改用 Ubuntu 24.04 LTS（64 位）后重试"* ]]
  [[ "$system_advice_output" == *"重装前请备份数据"* ]]
  apt-get() { :; }
  OS_RELEASE_FILE="$platform_fixture"
  printf "%s\n" \
    "ID=ubuntu" \
    "VERSION_ID=\"24.04\"" \
    "PRETTY_NAME=\"Ubuntu 24.04 LTS\"" >"$platform_fixture"
  check_platform
  printf "%s\n" \
    "ID=rocky" \
    "VERSION_ID=\"9.6\"" \
    "PRETTY_NAME=\"Rocky Linux 9.6\"" >"$platform_fixture"
  set +e
  unsupported_system_output="$(check_platform 2>&1)"
  unsupported_system_status=$?
  set -e
  [[ "$unsupported_system_status" -ne 0 ]]
  [[ "$unsupported_system_output" == *"当前系统 Rocky Linux 9.6 不受支持"* ]]
  [[ "$unsupported_system_output" == *"请改用 Ubuntu 24.04 LTS（64 位）后重试"* ]]
  [[ "$unsupported_system_output" == *"Ubuntu 24.04 LTS"* ]]
  printf "%s\n" \
    "ID=ubuntu" \
    "VERSION_ID=\"20.04\"" \
    "PRETTY_NAME=\"Ubuntu 20.04 LTS\"" >"$platform_fixture"
  set +e
  unsupported_version_output="$(check_platform 2>&1)"
  unsupported_version_status=$?
  set -e
  [[ "$unsupported_version_status" -ne 0 ]]
  [[ "$unsupported_version_output" == *"Ubuntu 20.04 LTS 不在支持范围内"* ]]
  OS_RELEASE_FILE="/etc/os-release"
  unset -f apt-get
  xui_fixture_db="$panel_fixture_dir/x-ui.db"
  sui_fixture_db="$panel_fixture_dir/s-ui.db"
  : >"$xui_fixture_db"
  : >"$sui_fixture_db"
  sqlite3() {
    local database="" argument query
    query="${!#}"
    for argument in "$@"; do
      [[ "$argument" == "$xui_fixture_db" || "$argument" == "$sui_fixture_db" ]] \
        && database="$argument"
    done
    case "$query" in
      *"sqlite_master"*"settings"*|*"sqlite_master"*"inbounds"*) printf "1\n" ;;
      *"SELECT value FROM settings"*)
        if [[ "$database" == "$xui_fixture_db" ]]; then
          printf "2053\n2096\n"
        else
          printf "2095\n2096\n"
        fi
        ;;
      *"SELECT port FROM inbounds"*) printf "443\n62010\n0\n70000\n" ;;
      *"json_extract(options"*) printf "8443\n62011\n" ;;
    esac
  }
  PANEL_RESERVED_PORTS=()
  collect_xui_database_ports "$xui_fixture_db"
  collect_sui_database_ports "$sui_fixture_db"
  [[ "${#PANEL_RESERVED_PORTS[@]}" == "7" ]]
  panel_port_is_reserved "2053"
  panel_port_is_reserved "2095"
  panel_port_is_reserved "62010"
  panel_port_is_reserved "62011"
  ! panel_port_is_reserved "63000"
  unset -f sqlite3

  port_is_common_or_panel_port "80"
  port_is_common_or_panel_port "443"
  port_is_common_or_panel_port "2095"
  port_is_common_or_panel_port "2096"
  port_is_common_or_panel_port "54321"
  ! port_is_common_or_panel_port "62001"

  unset XRAY_CHAIN_PORT
  collect_panel_reserved_ports() { PANEL_RESERVED_PORTS=("62010"); }
  AUTO_TEST_CALLS=0
  generate_auto_port_candidate() {
    ((AUTO_TEST_CALLS += 1))
    if [[ "$AUTO_TEST_CALLS" == "1" ]]; then
      AUTO_PORT_CANDIDATE="62010"
    else
      AUTO_PORT_CANDIDATE="62011"
    fi
  }
  port_is_listening() { return 1; }
  warn() { :; }
  info() { :; }

  prompt_yes_no prompt_result "fixture" no <<<"y"
  [[ "$prompt_result" == "yes" ]]
  prompt_yes_no prompt_result "fixture" no <<<"n"
  [[ "$prompt_result" == "no" ]]
  prompt_yes_no prompt_result "fixture" no <<<""
  [[ "$prompt_result" == "no" ]]
  prompt_yes_no prompt_result "fixture" yes <<<""
  [[ "$prompt_result" == "yes" ]]
  printf -v prompt_input "invalid\nn"
  prompt_yes_no prompt_result "fixture" no <<<"$prompt_input"
  [[ "$prompt_result" == "no" ]]
  confirm_destructive_action "fixture" <<<"y"
  ! confirm_destructive_action "fixture" <<<"n"
  set +e
  prompt_eof_output="$( (prompt_default prompt_result "测试输入" "默认值" </dev/null) 2>&1 )"
  prompt_eof_status=$?
  set -e
  [[ "$prompt_eof_status" -ne 0 ]]
  [[ "$prompt_eof_output" == *"未读取到输入：测试输入。"* ]]

  (
    show_socks_promo() { :; }
    read_hidden_socks_batch_input() { SOCKS_BATCH_RAW=""; }
    ADD_DIRECT_NODE="no"
    collect_socks_batch_settings
    [[ "$ADD_DIRECT_NODE" == "yes" ]]
    [[ "${#SOCKS_BATCH_ENTRIES[@]}" == "0" ]]
  )
  (
    detect_public_ipv4() { printf "198.51.100.88"; }
    SOCKS_EXIT_IP=""
    verify_direct_outbound
    [[ "$SOCKS_EXIT_IP" == "198.51.100.88" ]]
  )
  set +e
  (
    detect_public_ipv4() { :; }
    verify_direct_outbound
  ) >/dev/null 2>&1
  direct_detection_status=$?
  set -e
  [[ "$direct_detection_status" -ne 0 ]]

  select_inbound_port
  [[ "$INBOUND_PORT" == "62011" ]]

  set +e
  (
    XRAY_CHAIN_PORT="62010"
    select_inbound_port
  ) >/dev/null 2>&1
  saved_panel_conflict_status=$?
  set -e
  [[ "$saved_panel_conflict_status" -ne 0 ]]

  XRAY_CHAIN_PORT="443"
  port_is_listening() { return 1; }
  select_inbound_port
  [[ "$INBOUND_PORT" == "443" ]]
  unset XRAY_CHAIN_PORT

  set +e
  (
    XRAY_CHAIN_PORT="443"
    port_is_listening() { return 0; }
    select_inbound_port
  ) >/dev/null 2>&1
  explicit_conflict_status=$?
  set -e
  [[ "$explicit_conflict_status" -ne 0 ]]

  set +e
  (
    unset XRAY_CHAIN_PORT
    collect_panel_reserved_ports() { PANEL_RESERVED_PORTS=(); }
    generate_auto_port_candidate() { AUTO_PORT_CANDIDATE="63000"; }
    port_is_listening() { return 0; }
    select_inbound_port
  ) >/dev/null 2>&1
  all_ports_status=$?
  set -e
  [[ "$all_ports_status" -ne 0 ]]

  C_PAW_FILL="<white>"
  C_RESET="</>"
  C_BOLD="<bold>"
  C_GREEN="<green>"
  banner_output="$(show_brand_banner)"
  [[ "$banner_output" == *"<white>██</>"* ]]
  [[ "$banner_output" == *"PuppyIP.com"* ]]
  [[ "$banner_output" == *"https://puppyip.com/tutorials#"* ]]
  [[ "$banner_output" == *"选择：VPS配置教程 → VPS 链式代理配置"* ]]
  BRAND_BANNER_SHOWN="no"
  refresh_brand_banner >"$panel_fixture_dir/banner-first"
  refresh_brand_banner >"$panel_fixture_dir/banner-second"
  grep -Fq "PuppyIP.com" "$panel_fixture_dir/banner-first"
  [[ ! -s "$panel_fixture_dir/banner-second" ]]
  TUTORIAL_HINT_SHOWN="no"
  show_brand_footer >"$panel_fixture_dir/footer-first"
  show_brand_footer >"$panel_fixture_dir/footer-second"
  grep -Fq "https://puppyip.com/tutorials#" "$panel_fixture_dir/footer-first"
  ! grep -Fq "https://puppyip.com/tutorials#" "$panel_fixture_dir/footer-second"
  promo_output="$(show_socks_promo)"
  [[ "$promo_output" == *"PuppyIP.com"* ]]
  [[ "$promo_output" == *"原生住宅静态 IP"* ]]
  [[ "$promo_output" == *"直接回车 = 使用 VPS 本机 IP"* ]]
  [[ "$promo_output" == *"支持批量，最多 50 条"* ]]
  [[ "$promo_output" == *"IP:端口:用户名:密码"* ]]
  [[ "$promo_output" != *"请仅用于当地法律与服务条款允许的合规业务"* ]]
  edit_promo_output="$(show_socks_promo edit)"
  [[ "$edit_promo_output" == *"直接回车 = 保留当前出口"* ]]
  [[ "$edit_promo_output" != *"支持批量"* ]]
  menu_output="$(show_menu)"
  [[ "$menu_output" == *"1) 新增本机直连或批量 SOCKS5 出口"* ]]
  [[ "$menu_output" == *"2) 查看线路、链接和二维码"* ]]
  [[ "$menu_output" == *"3) 更换线路的出口 IP"* ]]
  [[ "$menu_output" == *"4) 暂停或启用线路"* ]]
  [[ "$menu_output" == *"6) 重新生成线路链接（旧链接会失效）"* ]]
  [[ "$menu_output" == *"7) 检查是否正常运行"* ]]
  [[ "$menu_output" == *"10) 卸载 PuppyIP Chain"* ]]
  original_script_source="$SCRIPT_SOURCE"
  SCRIPT_SOURCE="$MANAGER_BIN"
  running_as_installed_manager
  SCRIPT_SOURCE="$LEGACY_MANAGER_BIN"
  running_as_installed_manager
  SCRIPT_SOURCE="/dev/fd/999999"
  ! running_as_installed_manager
  SCRIPT_SOURCE="$original_script_source"

  upgrade_source="$(declare -f command_upgrade)"
  existing_remote_source="$(declare -f handle_existing_remote_run)"
  [[ "$upgrade_source" != *"print_node_list_file"* ]]
  [[ "$existing_remote_source" != *"print_node_list_file"* ]]
  [[ "$existing_remote_source" == *"command_add"* ]]

  semantic_version_is_newer "0.2.17" "0.2.16"
  semantic_version_is_newer "1.0.0" "0.99.99"
  ! semantic_version_is_newer "0.2.16" "0.2.16"
  ! semantic_version_is_newer "0.2.15" "0.2.16"
  ! semantic_version_is_newer "legacy" "0.2.16"

  (
    upgrade_fixture_dir="$panel_fixture_dir/existing-upgrade"
    mkdir -p "$upgrade_fixture_dir"
    STATE_FILE="$upgrade_fixture_dir/state.json"
    MANAGER_BIN="$upgrade_fixture_dir/puppyip"
    LEGACY_MANAGER_BIN="$upgrade_fixture_dir/xray-chain"
    printf "%s\n" \
      "{\"schema\":1,\"installerVersion\":\"0.2.15\"}" >"$STATE_FILE"
    printf "%s\n" "SCRIPT_VERSION=\"0.2.15\"" >"$MANAGER_BIN"
    printf "%s\n" "SCRIPT_VERSION=\"0.2.15\"" >"$LEGACY_MANAGER_BIN"
    require_root() { :; }
    check_platform() { :; }
    require_systemd() { :; }
    show_brand_banner() { :; }
    info() { printf '%s\n' "$*"; }
    UPGRADE_CALLED="no"
    ADD_CALLED="no"
    command_upgrade() { UPGRADE_CALLED="yes"; }
    command_add() { ADD_CALLED="yes"; }

    cancel_output="$(handle_existing_remote_run <<<"n")"
    [[ "$UPGRADE_CALLED" == "no" ]]
    [[ "$ADD_CALLED" == "no" ]]
    [[ "$cancel_output" == *"管理菜单：输入 puppyip"* ]]

    handle_existing_remote_run <<<"y"
    [[ "$UPGRADE_CALLED" == "yes" ]]
    [[ "$ADD_CALLED" == "yes" ]]

    jq --arg version "$SCRIPT_VERSION" \
      ".schema = 2 | .installerVersion = \$version" "$STATE_FILE" >"${STATE_FILE}.new"
    mv -f -- "${STATE_FILE}.new" "$STATE_FILE"
    printf "%s\n" "SCRIPT_VERSION=\"${SCRIPT_VERSION}\"" >"$MANAGER_BIN"
    printf "%s\n" "SCRIPT_VERSION=\"${SCRIPT_VERSION}\"" >"$LEGACY_MANAGER_BIN"
    UPGRADE_CALLED="no"
    ADD_CALLED="no"
    handle_existing_remote_run </dev/null
    [[ "$UPGRADE_CALLED" == "no" ]]
    [[ "$ADD_CALLED" == "yes" ]]
    ! installation_upgrade_needed

    printf "%s\n" "SCRIPT_VERSION=\"9.0.0\"" >"$MANAGER_BIN"
    set +e
    (assert_upgrade_not_downgrade) >/dev/null 2>&1
    downgrade_status=$?
    set -e
    [[ "$downgrade_status" -ne 0 ]]
  )

  (
    partial_fixture_dir="$panel_fixture_dir/partial-install"
    mkdir -p "$partial_fixture_dir"
    STATE_FILE="$partial_fixture_dir/state.json"
    CONFIG_FILE="$partial_fixture_dir/config.json"
    XRAY_BIN="$partial_fixture_dir/xray"
    SERVICE_FILE="$partial_fixture_dir/xray-chain.service"
    printf "%s\n" "{\"schema\":2}" >"$STATE_FILE"
    require_root() { :; }
    check_platform() { :; }
    require_systemd() { :; }
    show_brand_banner() { :; }
    initialize_model() { : >"$partial_fixture_dir/reinitialized"; }
    set +e
    (command_install) >/dev/null 2>&1
    partial_install_status=$?
    set -e
    [[ "$partial_install_status" -ne 0 ]]
    [[ ! -e "$partial_fixture_dir/reinitialized" ]]
  )

  new_temp_dir
  fixture_dir="$LAST_TEMP_DIR"
  STATE_FILE="$fixture_dir/state.json"
  cat >"$STATE_FILE" <<JSON
{
  "schema": 2,
  "serverAddress": "198.51.100.20",
  "inboundPort": 443,
  "serverName": "www.bing.com",
  "realityPublicKey": "fixture-public-key",
  "nodes": [
    {
      "id": "node-1",
      "number": 1,
      "name": "PuppyIP-203.0.113.10",
      "uuid": "3d107e9d-771a-41a8-88f3-94a9747a8f27",
      "shortId": "0123456789abcdef",
      "spiderX": "/0123456789abcdef",
      "udpMode": "block",
      "socksHost": "203.0.113.10",
      "socksPort": 1080,
      "socksUser": "fixture-user",
      "exitIp": "203.0.113.10"
    },
    {
      "id": "node-2",
      "number": 2,
      "name": "PuppyIP-198.51.100.30",
      "uuid": "8a235935-76a2-412a-97c6-57f71591aa45",
      "shortId": "fedcba9876543210",
      "spiderX": "/fedcba9876543210",
      "udpMode": "block",
      "enabled": false,
      "socksHost": "198.51.100.30",
      "socksPort": 2080,
      "socksUser": "fixture-user-2",
      "exitIp": "198.51.100.30"
    }
  ]
}
JSON
  share_link="$(build_share_link 1)"
  [[ "$share_link" == vless://3d107e9d-771a-41a8-88f3-94a9747a8f27@198.51.100.20:443\?* ]]
  [[ "$share_link" == *"spx=%2F0123456789abcdef"* ]]
  [[ "$share_link" == *"#PuppyIP-203.0.113.10"* ]]
  connection_output="$(show_connection 1)"
  [[ "$connection_output" == *"$share_link"* ]]
  [[ "$connection_output" == *"PuppyIP.com"* ]]
  [[ "$connection_output" == *"原生住宅静态 IP · 固定地区 · 长期使用"* ]]
  multi_connection_output="$(show_connections_by_id node-1 node-2)"
  [[ "$multi_connection_output" == *"PuppyIP-203.0.113.10"* ]]
  [[ "$multi_connection_output" == *"PuppyIP-198.51.100.30"* ]]
  [[ "$multi_connection_output" == *"状态：已暂停（链接已保留）"* ]]
  [[ "$(grep -Fc "原生住宅静态 IP · 固定地区 · 长期使用" <<<"$multi_connection_output")" == "1" ]]
  node_list_output="$(print_node_list_file "$STATE_FILE")"
  [[ "$node_list_output" == *"状态：已启用"* ]]
  [[ "$node_list_output" == *"状态：已暂停（原链接已保留）"* ]]
  status_state_is_valid 2
  (
    STATE_FILE="$fixture_dir/invalid-status-state.json"
    printf "%s\n" "{\"schema\":2,\"inboundPort\":443,\"nodes\":[]}" >"$STATE_FILE"
    ! status_state_is_valid 2
  )

  original_config_file="$CONFIG_FILE"
  status_fixture_dir="$fixture_dir/status-probes"
  mkdir -p "$status_fixture_dir"/{normal,mismatch,failed,unavailable}
  CONFIG_FILE="$status_fixture_dir/config.json"
  cat >"$CONFIG_FILE" <<JSON
{
  "outbounds": [
    {
      "tag": "socks-out-node-1",
      "protocol": "socks",
      "settings": {
        "address": "203.0.113.10",
        "port": 1080,
        "user": "fixture-user",
        "pass": "fixture-password"
      }
    },
    {
      "tag": "socks-out-node-2",
      "protocol": "socks",
      "settings": {
        "address": "198.51.100.30",
        "port": 2080,
        "user": "fixture-user-2",
        "pass": "fixture-password-2"
      }
    }
  ]
}
JSON
  status_output="$(
    interactive_progress_enabled() { return 1; }
    curl() {
      local config_path=""
      while (( $# > 0 )); do
        if [[ "$1" == "--config" ]]; then
          config_path="$2"
          shift 2
        else
          shift
        fi
      done
      grep -Fq "proxy = \"socks5h://203.0.113.10:1080\"" "$config_path"
      grep -Fq "proxy-user = \"fixture-user:fixture-password\"" "$config_path"
      printf "203.0.113.10\n"
    }
    show_status_node_health 2 "$status_fixture_dir/normal" ""
  )"
  [[ "$status_output" == *"线路出口检测（实时）"* ]]
  [[ "$status_output" == *"出口 IP：203.0.113.10 · 正常"* ]]
  [[ "$status_output" == *"状态：已暂停（未检测）"* ]]
  [[ "$status_output" != *"fixture-password"* ]]

  direct_result_file="$status_fixture_dir/normal/direct.result"
  (
    detect_public_ipv4() { printf "192.0.2.44"; }
    probe_status_node node-3 direct 2 "$status_fixture_dir/normal" "$direct_result_file"
  )
  mapfile -t direct_result <"$direct_result_file"
  [[ "${direct_result[0]}" == "ok" ]]
  [[ "${direct_result[1]}" == "192.0.2.44" ]]

  mismatch_output="$(
    interactive_progress_enabled() { return 1; }
    curl() { printf "198.51.100.99\n"; }
    show_status_node_health 2 "$status_fixture_dir/mismatch" ""
  )"
  [[ "$mismatch_output" == *"出口 IP：198.51.100.99 · 与记录不一致（记录：203.0.113.10）"* ]]
  [[ "$mismatch_output" != *"出口 IP：198.51.100.99 · 正常"* ]]

  failed_output="$(
    interactive_progress_enabled() { return 1; }
    curl() { return 1; }
    show_status_node_health 2 "$status_fixture_dir/failed" ""
  )"
  [[ "$failed_output" == *"出口检测：失败（请检查 SOCKS5、白名单或网络）"* ]]

  unavailable_output="$(
    interactive_progress_enabled() { return 1; }
    curl() { printf "不应执行" >"$status_fixture_dir/unexpected-curl"; }
    show_status_node_health 2 "$status_fixture_dir/unavailable" "服务未运行"
  )"
  [[ "$unavailable_output" == *"状态：不可用（服务未运行）"* ]]
  [[ ! -e "$status_fixture_dir/unexpected-curl" ]]

  original_xray_bin="$XRAY_BIN"
  original_asset_dir="$ASSET_DIR"
  XRAY_BIN="$status_fixture_dir/fake-xray"
  ASSET_DIR="$status_fixture_dir/assets"
  mkdir -p "$ASSET_DIR"
  printf "%s\n" \
    "#!/usr/bin/env bash" \
    "if [[ \"\${1:-}\" == \"version\" ]]; then" \
    "  printf \"Xray 26.3.27 fixture\\n\"" \
    "fi" \
    "exit 0" >"$XRAY_BIN"
  chmod 0755 "$XRAY_BIN"
  status_command_output="$(
    require_root() { :; }
    status_tcp_port_is_listening() { return 0; }
    systemctl() { printf "active\n"; }
    read_sysctl_value() {
      if [[ "$1" == "net.ipv4.tcp_congestion_control" ]]; then
        printf "bbr"
      else
        printf "fq"
      fi
    }
    interactive_progress_enabled() { return 1; }
    curl() { printf "203.0.113.10\n"; }
    command_status
  )"
  [[ "$status_command_output" == *"服务：正常"* ]]
  [[ "$status_command_output" == *"配置：正常"* ]]
  [[ "$status_command_output" == *"入口：443/tcp（监听中）"* ]]
  [[ "$status_command_output" == *"出口 IP：203.0.113.10 · 正常"* ]]

  unlistening_status_output="$(
    require_root() { :; }
    status_tcp_port_is_listening() { return 1; }
    systemctl() { printf "active\n"; }
    read_sysctl_value() { printf "unknown"; }
    interactive_progress_enabled() { return 1; }
    curl() { printf "不应执行" >"$status_fixture_dir/unlistening-unexpected-curl"; }
    command_status
  )"
  [[ "$unlistening_status_output" == *"入口：443/tcp（未监听）"* ]]
  [[ "$unlistening_status_output" == *"状态：不可用（入口端口未监听）"* ]]
  [[ ! -e "$status_fixture_dir/unlistening-unexpected-curl" ]]

  inactive_status_output="$(
    require_root() { :; }
    status_tcp_port_is_listening() { return 0; }
    systemctl() { printf "inactive\n"; return 3; }
    read_sysctl_value() { printf "unknown"; }
    interactive_progress_enabled() { return 1; }
    curl() { printf "不应执行" >"$status_fixture_dir/inactive-unexpected-curl"; }
    command_status
  )"
  [[ "$inactive_status_output" == *"服务：异常（inactive）"* ]]
  [[ "$inactive_status_output" == *"状态：不可用（服务未运行）"* ]]
  [[ ! -e "$status_fixture_dir/inactive-unexpected-curl" ]]
  XRAY_BIN="$original_xray_bin"
  ASSET_DIR="$original_asset_dir"
  CONFIG_FILE="$original_config_file"

  quiet_test_dir="$fixture_dir/quiet"
  mkdir -p "$quiet_test_dir"
  dpkg-query() { return 1; }
  qrencode() { :; }
  APT_CALLS=0
  apt-get() {
    ((APT_CALLS += 1))
    printf "这段模拟的 apt 输出不应显示在终端：%s\n" "$*"
  }
  install_dependencies "$quiet_test_dir" \
    >"$quiet_test_dir/terminal-stdout" 2>"$quiet_test_dir/terminal-stderr"
  [[ "$APT_CALLS" == "2" ]]
  [[ ! -s "$quiet_test_dir/terminal-stdout" ]]
  [[ ! -s "$quiet_test_dir/terminal-stderr" ]]
  grep -Fq "这段模拟的 apt 输出不应显示在终端" "$quiet_test_dir/dependencies.log"

  progress_test_dir="$fixture_dir/progress"
  mkdir -p "$progress_test_dir"
  original_progress_function="$(declare -f interactive_progress_enabled)"
  MOCK_PROGRESS_ENABLED="yes"
  MOCK_CURL_RECORD="$progress_test_dir/curl-arguments"
  interactive_progress_enabled() { [[ "$MOCK_PROGRESS_ENABLED" == "yes" ]]; }
  curl() {
    local -a arguments=("$@")
    local index destination="" show_mock_progress="no"
    printf "%s\n" "$@" >"$MOCK_CURL_RECORD"
    for ((index = 0; index < ${#arguments[@]}; index++)); do
      if [[ "${arguments[$index]}" == "--output" ]]; then
        destination="${arguments[$((index + 1))]}"
      fi
      [[ "${arguments[$index]}" != "--progress-bar" ]] || show_mock_progress="yes"
    done
    [[ -n "$destination" ]]
    [[ "$show_mock_progress" != "yes" ]] \
      || printf "\r########################### 37.5%%" >&2
    sleep 0.25
    : >"$destination"
  }
  download_file "$progress_test_dir/interactive.zip" \
    "https://example.invalid/interactive.zip" 30 yes "下载测试文件" \
    >"$progress_test_dir/download-progress" 2>&1
  grep -Fqx -- "--progress-bar" "$MOCK_CURL_RECORD"
  ! grep -Fqx -- "--silent" "$MOCK_CURL_RECORD"
  grep -Fq -- "37%" "$progress_test_dir/download-progress"
  grep -Fq -- "100%" "$progress_test_dir/download-progress"
  MOCK_PROGRESS_ENABLED="no"
  download_file "$progress_test_dir/non-interactive.zip" \
    "https://example.invalid/non-interactive.zip" 30 yes
  grep -Fqx -- "--silent" "$MOCK_CURL_RECORD"
  ! grep -Fqx -- "--progress-bar" "$MOCK_CURL_RECORD"
  MOCK_PROGRESS_ENABLED="yes"
  SOCKS_BATCH_RAW=""
  read_hidden_socks_batch_input "SOCKS5: " <<<"fixture-secret" \
    >"$progress_test_dir/prompt-output"
  [[ "$SOCKS_BATCH_RAW" == "fixture-secret" ]]
  prompt_escape="$(printf "\033")"
  grep -Fq "${prompt_escape}[2A" "$progress_test_dir/prompt-output"
  grep -Fq "${prompt_escape}[2K" "$progress_test_dir/prompt-output"
  grep -Fq "输入会隐藏，粘贴后按回车" "$progress_test_dir/prompt-output"
  ! grep -Fq "直接回车 = 使用 VPS 本机 IP" "$progress_test_dir/prompt-output"
  failing_progress_task() { sleep 0.05; return 7; }
  set +e
  run_logged_task "模拟失败任务" "$progress_test_dir/failure.log" \
    failing_progress_task >"$progress_test_dir/progress-output" 2>&1
  progress_status=$?
  set -e
  [[ "$progress_status" == "7" ]]
  eval "$original_progress_function"
  unset -f curl failing_progress_task

  reuse_source="$fixture_dir/reuse-source"
  reuse_destination="$fixture_dir/reuse-destination"
  mkdir -p "$reuse_source/assets"
  XRAY_BIN="$reuse_source/xray"
  ASSET_DIR="$reuse_source/assets"
  STATE_FILE="$reuse_source/state.json"
  printf "fixture-xray" >"$XRAY_BIN"
  printf "fixture-geoip" >"$ASSET_DIR/geoip.dat"
  printf "fixture-geosite" >"$ASSET_DIR/geosite.dat"
  printf "{\"xrayVersion\":\"v26.3.27\"}" >"$STATE_FILE"
  chmod 0755 "$XRAY_BIN"
  state_value() {
    jq -er "$1 // empty" "$STATE_FILE" 2>/dev/null || printf "%s" "${2:-}"
  }
  stage_installed_xray "$reuse_destination"
  cmp -s "$XRAY_BIN" "$reuse_destination/xray/xray"
  cmp -s "$ASSET_DIR/geoip.dat" "$reuse_destination/xray/geoip.dat"
  cmp -s "$ASSET_DIR/geosite.dat" "$reuse_destination/xray/geosite.dat"
  [[ "$(<"$reuse_destination/xray-version")" == "v26.3.27" ]]
  remote_manager="$fixture_dir/remote-manager"
  original_script_source="$SCRIPT_SOURCE"
  fixture_script_path="$1"
  SCRIPT_SOURCE="/dev/fd/999999"
  MOCK_MANAGER_URL=""
  curl() {
    local destination="" last_argument=""
    while (( $# > 0 )); do
      if [[ "$1" == "--output" ]]; then
        destination="$2"
        shift 2
      else
        last_argument="$1"
        shift
      fi
    done
    if [[ -n "$destination" ]]; then
      MOCK_MANAGER_URL="$last_argument"
      cp -- "$fixture_script_path" "$destination"
    else
      printf "%s\n" \
        "{\"object\":{\"sha\":\"0123456789abcdef0123456789abcdef01234567\"}}"
    fi
  }
  prepare_manager_copy "$remote_manager"
  grep -Fqx "SCRIPT_VERSION=\"${SCRIPT_VERSION}\"" "$remote_manager"
  [[ -x "$remote_manager" ]]
  [[ "$MOCK_MANAGER_URL" == \
    "https://raw.githubusercontent.com/feng9254/xray-chain-installer/0123456789abcdef0123456789abcdef01234567/install.sh" ]]
  unset -f curl
  SCRIPT_SOURCE="$original_script_source"
  bbr_test_dir="$fixture_dir/bbr"
  DATA_DIR="$bbr_test_dir/data"
  BBR_STATE_FILE="$DATA_DIR/bbr-state.json"
  BBR_SYSCTL_FILE="$bbr_test_dir/sysctl/99-zz-puppyip-bbr.conf"
  BBR_MODULES_FILE="$bbr_test_dir/modules/puppyip-bbr.conf"
  mkdir -p "$DATA_DIR"
  MOCK_CC="cubic"
  MOCK_QDISC="fq_codel"
  MOCK_AVAILABLE="reno cubic bbr"
  MOCK_FAIL_BBR_APPLY="no"
  sysctl() {
    if [[ "$1" == "-n" ]]; then
      case "$2" in
        net.ipv4.tcp_congestion_control) printf "%s\n" "$MOCK_CC" ;;
        net.core.default_qdisc) printf "%s\n" "$MOCK_QDISC" ;;
        net.ipv4.tcp_available_congestion_control) printf "%s\n" "$MOCK_AVAILABLE" ;;
        *) return 1 ;;
      esac
      return 0
    fi
    if [[ "$1" == "-q" && "$2" == "-w" ]]; then
      case "$3" in
        net.ipv4.tcp_congestion_control=*)
          [[ "$MOCK_FAIL_BBR_APPLY" != "yes" || "${3#*=}" != "bbr" ]] || return 1
          MOCK_CC="${3#*=}"
          ;;
        net.core.default_qdisc=*) MOCK_QDISC="${3#*=}" ;;
        *) return 1 ;;
      esac
      return 0
    fi
    return 1
  }
  modprobe() { :; }
  systemctl() { return 1; }
  install() {
    [[ "$1" == "-d" ]] || return 1
    shift
    while (( $# > 0 )); do
      case "$1" in
        -o|-g|-m) shift 2 ;;
        *) mkdir -p "$1"; shift ;;
      esac
    done
  }
  atomic_install() {
    cp -- "$1" "$2"
    chmod "$3" "$2"
  }
  XRAY_CHAIN_ENABLE_BBR=1
  configure_bbr
  [[ "$BBR_CHANGED" == "yes" ]]
  [[ "$MOCK_CC" == "bbr" && "$MOCK_QDISC" == "fq" ]]
  grep -Fqx "net.ipv4.tcp_congestion_control = bbr" "$BBR_SYSCTL_FILE"
  grep -Fqx "tcp_bbr" "$BBR_MODULES_FILE"
  bbr_state_is_valid
  restore_bbr_settings
  [[ "$MOCK_CC" == "cubic" && "$MOCK_QDISC" == "fq_codel" ]]
  [[ ! -e "$BBR_STATE_FILE" && ! -e "$BBR_SYSCTL_FILE" && ! -e "$BBR_MODULES_FILE" ]]

  MOCK_CC="bbr"
  MOCK_QDISC="fq_codel"
  configure_bbr
  [[ "$BBR_CHANGED" == "no" ]]
  [[ "$MOCK_CC" == "bbr" && "$MOCK_QDISC" == "fq_codel" ]]
  [[ ! -e "$BBR_STATE_FILE" && ! -e "$BBR_SYSCTL_FILE" && ! -e "$BBR_MODULES_FILE" ]]

  MOCK_CC="cubic"
  MOCK_QDISC="fq_codel"
  MOCK_AVAILABLE="reno cubic"
  configure_bbr
  [[ "$BBR_CHANGED" == "no" ]]
  [[ "$MOCK_CC" == "cubic" && "$MOCK_QDISC" == "fq_codel" ]]
  [[ ! -e "$BBR_STATE_FILE" && ! -e "$BBR_SYSCTL_FILE" && ! -e "$BBR_MODULES_FILE" ]]

  MOCK_AVAILABLE="reno cubic bbr"
  printf "%s\n" "# administrator-owned" >"$BBR_SYSCTL_FILE"
  configure_bbr
  [[ "$BBR_CHANGED" == "no" ]]
  [[ "$(<"$BBR_SYSCTL_FILE")" == "# administrator-owned" ]]
  [[ "$MOCK_CC" == "cubic" && "$MOCK_QDISC" == "fq_codel" ]]
  rm -f -- "$BBR_SYSCTL_FILE"

  MOCK_FAIL_BBR_APPLY="yes"
  configure_bbr
  [[ "$BBR_CHANGED" == "no" ]]
  [[ "$MOCK_CC" == "cubic" && "$MOCK_QDISC" == "fq_codel" ]]
  [[ ! -e "$BBR_STATE_FILE" && ! -e "$BBR_SYSCTL_FILE" && ! -e "$BBR_MODULES_FILE" ]]
  MOCK_FAIL_BBR_APPLY="no"

  XRAY_CHAIN_ENABLE_BBR=0
  configure_bbr
  [[ "$MOCK_CC" == "cubic" && "$MOCK_QDISC" == "fq_codel" ]]
  unset -f sysctl modprobe systemctl install atomic_install
' _ "$SCRIPT"

if grep -En -- '--no-check-certificate|curl[^\n]*(--insecure|-k)([[:space:]]|$)|github[^\n]*(proxy|mirror)' "$SCRIPT"; then
  printf '发现不允许的不安全下载选项或第三方 GitHub 代理。\n' >&2
  exit 1
fi

for required in \
  'run -test -c' \
  'SHA2-256=' \
  'xtls-rprx-vision' \
  'security=reality' \
  'https://PuppyIP.com' \
  'https://puppyip.com/tutorials#' \
  '选择：VPS配置教程 → VPS 链式代理配置' \
  'PuppyIP.com' \
  '请改用 Ubuntu 24.04 LTS（64 位）后重试' \
  '原生住宅静态 IP · 固定地区 · 长期使用' \
  "C_PAW_FILL=\$'\\033[1;97m'" \
  'SOCKS5（支持批量，最多' \
  '直接回车 = 使用 VPS 本机 IP' \
  'y=同意 / n=不同意 / 回车=同意' \
  'y=同意 / n=不同意 / 回车=不同意' \
  'append_batch_nodes_to_model' \
  'direct-out-' \
  'AUTO_PORT_MIN=62001' \
  'AUTO_PORT_MAX=65534' \
  'INSTALLER_RAW_URL="https://raw.githubusercontent.com/feng9254/xray-chain-installer/main/install.sh"' \
  'INSTALLER_API_URL="https://api.github.com/repos/${INSTALLER_REPOSITORY}"' \
  '/git/ref/heads/${INSTALLER_BRANCH}' \
  'source_url="${INSTALLER_RAW_BASE}/${commit}/install.sh"' \
  'XRAY_CHAIN_ENABLE_BBR=1|0' \
  'confirm_destructive_action' \
  'net.ipv4.tcp_congestion_control = bbr' \
  'restore_bbr_settings' \
  'XRAY_CHAIN_PORT=62001' \
  'detect_existing_proxy_stacks' \
  'ss -H -lntu' \
  'sqlite3 -readonly' \
  "json_extract(options, '\$.listen_port')" \
  'socks-out-' \
  'user: [.email]' \
  'inboundTag: ["vless-in"]' \
  'nextNodeNumber' \
  'schema: 2' \
  'CURRENT_STATE_SCHEMA=2' \
  'LEGACY_MANAGER_BIN="/usr/local/sbin/xray-chain"' \
  'MANAGER_BIN="/usr/local/sbin/puppyip"' \
  'XRAY_CHAIN_UDP_MODE:-proxy' \
  '更换线路的出口 IP' \
  '暂停或启用线路' \
  'set_node_enabled_in_model' \
  'command_pause' \
  'command_resume' \
  'command_upgrade' \
  'handle_existing_remote_run' \
  'show_management_hint' \
  'probe_status_node' \
  '线路出口检测（实时）' \
  'assert_upgrade_invariants' \
  'canonical_runtime_identity' \
  '候选配置未完整保留 SOCKS5 凭据' \
  '脚本不会自动重新安装' \
  'if ! running_as_installed_manager; then' \
  'if installation_complete; then pause_menu; else exit 0; fi' \
  'rollback_backup'; do
  grep -Fq -- "$required" "$SCRIPT" || {
    printf '缺少关键实现：%s\n' "$required" >&2
    exit 1
  }
done

if grep -Fq '请输入 UNINSTALL 确认' "$SCRIPT"; then
  printf '卸载流程不应再要求输入确认单词。\n' >&2
  exit 1
fi

if grep -Fq '10) command_uninstall; exit 0 ;;' "$SCRIPT"; then
  printf '取消卸载后不应直接退出管理菜单。\n' >&2
  exit 1
fi

if grep -Fq '允许 UDP 经该 SOCKS5 上游转发吗？' "$SCRIPT"; then
  printf '普通更换出口流程不应再询问 UDP。\n' >&2
  exit 1
fi

for noisy_text in \
  '适用：v2rayN、Shadowrocket' \
  'UDP：尝试经 SOCKS5 转发' \
  'UDP：已在服务端阻断' \
  'UDP：经 VPS 本机网络直接发送' \
  '注意：REALITY 不需要传统 TLS 证书'; do
  if grep -Fq "$noisy_text" "$SCRIPT"; then
    printf '节点结果仍包含多余解释：%s\n' "$noisy_text" >&2
    exit 1
  fi
done

if grep -Fq '\033[2J' "$SCRIPT" || grep -Fq '\033[H' "$SCRIPT"; then
  printf '交互脚本不应清屏或重置光标；终端历史必须可以回看。\n' >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*curl[[:space:]]+--progress-bar' "$SCRIPT"; then
  printf 'curl 内置进度条不应直接连接到用户终端。\n' >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$SCRIPT" "${ROOT_DIR}/tests/static.sh" \
    "${ROOT_DIR}/tests/integration.sh" "${ROOT_DIR}/tests/preflight.sh" \
    "${ROOT_DIR}/tests/rollback.sh"
fi

printf '静态检查通过。\n'
