#!/usr/bin/env bash
# monitor.sh - 시스템 관제 자동화 스크립트
# 미션: B1-1 / docs/MISSION.md §4.4 구현
set -u

# ---------------------------------------------------------------------------
# 환경 변수 로드 (cron 환경에서는 /etc/profile.d/* 가 자동으로 source 되지
# 않으므로 명시적으로 로드한다.)
# ---------------------------------------------------------------------------
if [[ -f /etc/profile.d/agent-app.sh ]]; then
    # shellcheck disable=SC1091
    . /etc/profile.d/agent-app.sh
fi

: "${AGENT_LOG_DIR:=/var/log/agent-app}"
: "${AGENT_PORT:=15034}"

readonly APP_NAME="agent_app"
readonly LOG_FILE="${AGENT_LOG_DIR}/monitor.log"
readonly LOG_MAX_BYTES=$((10 * 1024 * 1024))   # 10 MiB
readonly LOG_MAX_FILES=10

readonly CPU_THRESHOLD=20
readonly MEM_THRESHOLD=10
readonly DISK_THRESHOLD=80

APP_PID=""

# ---------------------------------------------------------------------------
# Health Check
# ---------------------------------------------------------------------------
check_process() {
    local pid
    pid=$(pgrep -f "${APP_NAME}" | head -n1 || true)
    if [[ -z "${pid}" ]]; then
        echo "Checking process '${APP_NAME}'... [FAIL]"
        exit 1
    fi
    echo "Checking process '${APP_NAME}'... [OK] (PID: ${pid})"
    APP_PID="${pid}"
}

check_port() {
    if ss -tln "sport = :${AGENT_PORT}" | grep -q LISTEN; then
        echo "Checking port ${AGENT_PORT}... [OK]"
    else
        echo "Checking port ${AGENT_PORT}... [FAIL]"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# 방화벽 상태 (경고만, 종료하지 않음)
#   - 일반 사용자도 sudo 없이 호출 가능한 systemctl is-active 를 사용
# ---------------------------------------------------------------------------
check_firewall() {
    if ! systemctl is-active --quiet ufw; then
        echo "[WARNING] UFW is not active"
    fi
}

# ---------------------------------------------------------------------------
# 자원 수집
# ---------------------------------------------------------------------------
get_cpu_usage() {
    # /proc/stat 1초 간격 2회 샘플링 → 차분 기반 사용률(%)
    local line1 line2
    line1=$(grep -m1 '^cpu ' /proc/stat)
    sleep 1
    line2=$(grep -m1 '^cpu ' /proc/stat)

    # cpu user nice system idle iowait irq softirq steal
    local _ u1 n1 s1 i1 io1 ir1 sf1 st1
    local u2 n2 s2 i2 io2 ir2 sf2 st2
    read -r _ u1 n1 s1 i1 io1 ir1 sf1 st1 <<<"${line1}"
    read -r _ u2 n2 s2 i2 io2 ir2 sf2 st2 <<<"${line2}"

    local idle1=$(( i1 + io1 ))
    local idle2=$(( i2 + io2 ))
    local total1=$(( u1 + n1 + s1 + i1 + io1 + ir1 + sf1 + st1 ))
    local total2=$(( u2 + n2 + s2 + i2 + io2 + ir2 + sf2 + st2 ))

    local td=$(( total2 - total1 ))
    local id=$(( idle2 - idle1 ))
    if (( td <= 0 )); then
        echo "0.0"
        return
    fi
    awk -v t="${td}" -v i="${id}" 'BEGIN { printf "%.1f", (t - i) * 100.0 / t }'
}

get_mem_usage() {
    local total avail
    total=$(awk '/^MemTotal:/    { print $2; exit }' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo)
    awk -v t="${total}" -v a="${avail}" 'BEGIN { printf "%.1f", (t - a) * 100.0 / t }'
}

get_disk_usage() {
    df --output=pcent / | tail -n1 | tr -dc '0-9'
}

# ---------------------------------------------------------------------------
# 로그 회전 (10MB 초과 시 .1~.10 으로 시프트, 11번째부터 삭제)
# ---------------------------------------------------------------------------
rotate_log() {
    [[ -f "${LOG_FILE}" ]] || return 0
    local size
    size=$(stat -c '%s' "${LOG_FILE}" 2>/dev/null || echo 0)
    (( size < LOG_MAX_BYTES )) && return 0

    if [[ -f "${LOG_FILE}.${LOG_MAX_FILES}" ]]; then
        rm -f "${LOG_FILE}.${LOG_MAX_FILES}"
    fi
    local n
    for (( n = LOG_MAX_FILES - 1; n >= 1; n-- )); do
        if [[ -f "${LOG_FILE}.${n}" ]]; then
            mv "${LOG_FILE}.${n}" "${LOG_FILE}.$((n + 1))"
        fi
    done
    mv "${LOG_FILE}" "${LOG_FILE}.1"
}

# ---------------------------------------------------------------------------
# 임계값 비교 헬퍼 (실수 비교는 awk 로)
# ---------------------------------------------------------------------------
gt_float() {
    awk -v v="$1" -v t="$2" 'BEGIN { exit !(v > t) }'
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------
main() {
    echo "====== SYSTEM MONITOR RESULT ======"
    echo
    echo "[HEALTH CHECK]"
    check_process
    check_port
    check_firewall
    echo

    local cpu mem disk
    cpu=$(get_cpu_usage)
    mem=$(get_mem_usage)
    disk=$(get_disk_usage)

    echo "[RESOURCE MONITORING]"
    echo "CPU Usage : ${cpu}%"
    echo "MEM Usage : ${mem}%"
    echo "DISK Used : ${disk}%"
    echo

    if gt_float "${cpu}" "${CPU_THRESHOLD}"; then
        echo "[WARNING] CPU threshold exceeded (${cpu}% > ${CPU_THRESHOLD}%)"
    fi
    if gt_float "${mem}" "${MEM_THRESHOLD}"; then
        echo "[WARNING] MEM threshold exceeded (${mem}% > ${MEM_THRESHOLD}%)"
    fi
    if (( disk > DISK_THRESHOLD )); then
        echo "[WARNING] DISK threshold exceeded (${disk}% > ${DISK_THRESHOLD}%)"
    fi

    rotate_log
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${ts}] PID:${APP_PID} CPU:${cpu}% MEM:${mem}% DISK_USED:${disk}%" >> "${LOG_FILE}"

    echo
    echo "[INFO] Log appended: ${LOG_FILE}"
}

main "$@"
