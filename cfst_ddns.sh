#!/usr/bin/env bash
# =====================================================================
# CloudflareSpeedTest 自动 DDNS 更新脚本
# Author: AI
# Description: 检查依赖，仅在缺失时提示，运行 cfst 进行测速，提取最优 IP 并更新 Cloudflare DNS A/AAAA 记录
# Platform: Debian / Ubuntu
# =====================================================================

set -euo pipefail
IFS=$'\n\t'

# --- 配置区 (请填写您的 Cloudflare 信息) ---
CF_API_TOKEN=""    # 在 https://dash.cloudflare.com/profile/api-tokens 创建，要求 Zone.DNS - Edit
CF_ZONE_ID=""      # 在域名概述页右下角可见
DNS_NAME=""        # 完整的记录名称，如 sub.yourdomain.com
RECORD_TYPE="A"    # A 或 AAAA

# --- cfst 参数 (可根据需求调整) ---
# 以下列出所有 CloudflareSpeedTest 支持的常用参数，括号内为简要说明：
# -n <number>           延迟测速线程数 (默认 200，最大 1000)
# -t <times>            单 IP 延迟测速次数 (默认 4)
# -dn <number>          延迟排序后参与下载测速的 IP 数量 (默认 10)
# -dt <seconds>         单 IP 下载测速最长时间 (秒，默认 10)
# -tp <port>            指定测速端口 (TCP/HTTPing，将在延迟和下载测速时使用，默认 443)
# -url <URL>            指定测速地址 (HTTP 下载测速时使用)
# -httping              使用 HTTP 协议进行延迟测速 (默认 TCP)
# -httping-code <code>  HTTPing 延迟测速的有效 HTTP 状态码 (默认 200,301,302)
# -cfcolo <list>        指定地区 IATA 码，逗号分隔 (仅 HTTPing 模式)。可选值(需要根据网络环境确认)示例:
#                       SJC (San Jose), LAX (Los Angeles), SEA (Seattle)
#			SFO (San Francisco), IAD (Washington DC), EWR (Newark)
#			LHR (London), AMS (Amsterdam), FRA (Frankfurt)
#			HKG (Hong Kong), NRT (Tokyo), SYD (Sydney)
#			SIN (Singapore), CDG (Paris), DXB (Dubai)
# 			MAD (Madrid), YYZ (Toronto)
# -tl <ms>              平均延迟上限 (默认 9999 ms)
# -tll <ms>             平均延迟下限 (默认 0 ms)
# -tlr <ratio>          丢包率上限 (0~1，默认 1.00)
# -sl <MB/s>            下载速度下限 (MB/s，默认 0.00)
# -p <number>           显示结果数量 (0 时不输出结果，默认 10)
# -f <file>             从文件读取 IP 段数据 (默认 ip.txt)
# -ip <list>            直接指定要测速的 IP 段，逗号分隔
# -o <file>             将结果写入文件 (默认 result.csv)
# -dd                   禁用下载测速，仅按延迟排序
# -allip                对所有 IP 段中的每个 IP 进行测速 (仅 IPv4)
# -debug                调试模式，输出更多日志
# -v                    打印程序版本并检查更新
# -h                    打印帮助说明
CFST_PARAMS=(
  -n 1000    # 延迟测速线程数
  -t 6       # 每 IP 延迟测速次数
  -dn 6      # 延迟排序后下载测速数量
  -tll 40    # 平均延迟下限 (ms)
  -tl 160    # 平均延迟上限 (ms)
  -tlr 0.2   # 丢包率上限
  -sl 20     # 下载速度下限 (MB/s)
  -p 5       # 显示结果数量
  -url https://speedtest.xxxx.xyz/200m  # 测速地址
  -cfcolo SJC,LAX,SEA  # 指定地区
)

# 日志文件
LOG_FILE="${PWD}/update.log"

# 日志函数
tty_log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" >&2
}

# 检查依赖，仅在缺失时提示
check_deps() {
  local missing=0
  # 检测 curl 和 jq
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "错误: 依赖 '$cmd' 未安装。请安装后重试。" >&2
      missing=1
    fi
  done
  # 检测 cfst 可执行文件（支持当前目录）
  if [[ ! -x "./cfst" ]]; then
    echo "错误: 未找到可执行的 './cfst'。请确保 cfst 在脚本同一目录并有执行权限。" >&2
    missing=1
  fi
  [[ $missing -eq 0 ]] || exit 1
}

# 验证 Cloudflare 配置
validate_config() {
  if [[ -z "$CF_API_TOKEN" || -z "$CF_ZONE_ID" || -z "$DNS_NAME" ]]; then
    echo "请先编辑脚本，填入 CF_API_TOKEN、CF_ZONE_ID 和 DNS_NAME。" >&2
    exit 1
  fi
  if [[ "$RECORD_TYPE" != "A" && "$RECORD_TYPE" != "AAAA" ]]; then
    echo "RECORD_TYPE 必须为 A 或 AAAA" >&2
    exit 1
  fi
}

# 执行 cfst 测速，保留原生输出，生成 result.csv
run_speedtest() {
  ./cfst -o result.csv "${CFST_PARAMS[@]}"
  [[ -s result.csv ]] || { tty_log "错误: result.csv 不存在或为空"; exit 1; }
}

# 从 result.csv 提取最佳 IP（CloudflareSpeedTest 默认按下载速度降序排序，首行即最优）
extract_best_ip() {
  # 跳过表头取首行
  local ip
  ip=$(tail -n +2 result.csv | head -n1 | cut -d',' -f1)
  if [[ ! "$ip" =~ ^[0-9.:]+$ ]]; then
    tty_log "错误: 提取到的 IP 无效: $ip"
    exit 1
  fi
  echo "$ip"
}

# 更新 Cloudflare DNS 记录
update_dns() {
  local ip="$1"
  tty_log "更新 DNS 记录 $DNS_NAME ($RECORD_TYPE) -> $ip"

  # 获取记录 ID
  local rec_id resp api_url
  api_url="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=$RECORD_TYPE&name=$DNS_NAME"
  resp=$(curl --fail --silent --show-error \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    "$api_url")
  rec_id=$(echo "$resp" | jq -r '.result[0].id')
  if [[ -z "$rec_id" || "$rec_id" == "null" ]]; then
    tty_log "错误: 未找到记录 ID，检查 DNS_NAME 和 CFZONE_ID"; exit 1
  fi

  # 更新内容
  api_url="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$rec_id"
  curl --fail --silent --show-error -X PUT \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"'"$RECORD_TYPE"'","name":"'"$DNS_NAME"'","content":"'"$ip"'"}' \
    "$api_url" >/dev/null

  tty_log "DNS 更新完成：$DNS_NAME -> $ip"
}

# 主流程
validate_config
check_deps
run_speedtest
best_ip=$(extract_best_ip)
update_dns "$best_ip"
tty_log "脚本执行完成。"
