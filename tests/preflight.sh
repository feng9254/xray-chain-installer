#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

command -v git >/dev/null 2>&1 || {
  printf '缺少 git，无法执行发布前检查。\n' >&2
  exit 1
}
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  printf '当前目录不是 Git 仓库。\n' >&2
  exit 1
}

printf '发布前检查：工作树与补丁格式...\n'
git diff --check
git diff --cached --check

secret_pattern='AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{48}|sk-ant-[A-Za-z0-9-]{80,}|gh[pousr]_[A-Za-z0-9]{36,}|glpat-[A-Za-z0-9_-]{20,}|xoxb-[0-9]{10,}-[A-Za-z0-9]{20,}|SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{40,}|-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----|-----BEGIN PGP PRIVATE KEY BLOCK-----|(postgres|mysql|mongodb)://[^[:space:]]+:[^[:space:]]+@|socks5h?://[^[:space:]]+:[^[:space:]@]+@'
share_link_pattern='vless://[0-9A-Fa-f-]{36}@'

printf '发布前检查：敏感文件名与本机路径...\n'
mapfile -t sensitive_paths < <(
  {
    git ls-files
    git ls-files --others --exclude-standard
  } | sort -u \
    | grep -Ei '(^|/)(\.env($|\.)|id_(rsa|ed25519)$|\.netrc$|\.npmrc$|\.pypirc$|secrets?\.json$|config\.json$)|\.(key|pem|p12|pfx|pcap|har)$' \
    | grep -Ev '(^|/)\.env\.example$' \
    || true
)
if (( ${#sensitive_paths[@]} > 0 )); then
  printf '发现不应发布的敏感文件名；为避免泄露，未显示路径。\n' >&2
  exit 1
fi

if git grep --untracked -I -q -E '(C:\\Users\\|/Users/[^/[:space:]]+|/home/[^/[:space:]]+)' -- \
  . ':(exclude)tests/preflight.sh'; then
  printf '发现疑似本机绝对路径；为避免暴露开发环境，未显示具体内容。\n' >&2
  exit 1
fi

printf '发布前检查：当前受跟踪及未跟踪文本中的高置信度凭据...\n'
mapfile -t secret_files < <(
  git grep --untracked -I -l -E "$secret_pattern" -- \
    . \
    ':(exclude)tests/preflight.sh' \
    || true
)
mapfile -t share_link_files < <(
  git grep --untracked -I -l -E "$share_link_pattern" -- \
    . \
    ':(exclude)tests/**' \
    || true
)
if (( ${#secret_files[@]} > 0 || ${#share_link_files[@]} > 0 )); then
  printf '发现疑似敏感信息；为避免泄露，不显示文件名或命中内容。\n' >&2
  exit 1
fi

printf '发布前检查：Git 历史中的高置信度凭据...\n'
history_secret_found='no'
while IFS= read -r commit; do
  if git grep -I -q -E "$secret_pattern" "$commit" -- \
      . \
      ':(exclude)tests/preflight.sh' \
    || git grep -I -q -E "$share_link_pattern" "$commit" -- \
      . \
      ':(exclude)tests/**'; then
    history_secret_found='yes'
    break
  fi
done < <(git rev-list --all --reflog)
if [[ "$history_secret_found" == 'yes' ]]; then
  printf 'Git 历史中发现疑似凭据；请先轮换并清理历史。未显示提交或原文。\n' >&2
  exit 1
fi

printf '发布前检查：所有文本只使用保留或私网 IPv4 示例...\n'
public_ip_count="$(
  {
    git grep --untracked -I -h -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' -- \
      . \
      || true
  } | awk -F. '
    $1 > 255 || $2 > 255 || $3 > 255 || $4 > 255 {next}
    $1 == 0 || $1 == 10 || $1 == 127 {next}
    $1 == 169 && $2 == 254 {next}
    $1 == 172 && $2 >= 16 && $2 <= 31 {next}
    $1 == 192 && $2 == 168 {next}
    $1 == 192 && $2 == 0 && $3 == 2 {next}
    $1 == 198 && $2 == 51 && $3 == 100 {next}
    $1 == 203 && $2 == 0 && $3 == 113 {next}
    {count += 1}
    END {print count + 0}
  '
)"
if (( public_ip_count > 0 )); then
  printf '发现非文档用途的公网 IPv4；为避免泄露，未显示具体地址。\n' >&2
  exit 1
fi

printf '发布前检查：公开 README 不包含开发过程文案...\n'
if grep -Eq '首次 VPS 实测（发布前）|验证开发副本|VPS_IP|scp[[:space:]]+install\.sh|上传到你自己的仓库|正式发布后|本轮(不|暂不|先不)|广告顶出画面|悬浮输入栏|安全间距|FinalShell|固定宽度的单行进度条|^## 发布前检查$' README.md; then
  printf 'README.md 仍包含开发或内部发布流程，请先清理。\n' >&2
  exit 1
fi

if grep -Eq '广告顶出画面|悬浮输入栏|安全间距|FinalShell' install.sh; then
  printf 'install.sh 仍包含面向特定终端的内部设计说明，请先清理。\n' >&2
  exit 1
fi

if grep -Eq '^SCRIPT_VERSION="[^"]*(-dev|-alpha|-beta|-rc[0-9]*)"$' install.sh; then
  printf 'install.sh 仍使用预发布版本号，请先改为正式版本。\n' >&2
  exit 1
fi

for declaration in \
  '不保证匿名' \
  'SOCKS5 本身不提供加密' \
  '公开可见不等于放弃版权' \
  '不要附带真实节点、配置、日志、二维码或凭据'; do
  grep -Fq "$declaration" README.md || {
    printf 'README.md 缺少必要的公开声明。\n' >&2
    exit 1
  }
done

[[ -r SECURITY.md ]] || {
  printf '缺少 SECURITY.md 敏感信息报告说明。\n' >&2
  exit 1
}

for ignore_rule in '.env' '*.key' '*.pem' 'state.json' 'secrets.json' 'backups/' '*.pcap' '*.har'; do
  grep -Fqx "$ignore_rule" .gitignore || {
    printf '.gitignore 缺少敏感运行产物规则：%s\n' "$ignore_rule" >&2
    exit 1
  }
done

if git log --all --format='%ae' \
  | awk 'NF && $0 !~ /@users\.noreply\.github\.com$/ {found=1} END {exit !found}'; then
  printf 'Git 历史包含非 GitHub noreply 提交邮箱；为避免公开身份信息，发布前检查已停止。\n' >&2
  exit 1
fi

printf '发布前检查通过：未输出任何凭据原文。\n'
