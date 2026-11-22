#!/usr/bin/env bash

# ============================================================
# LOGPULSE - INTERACTIVE LOG ANALYTICS DASHBOARD
# Pure Bash | Kali Linux | Ubuntu | SSH Compatible
# ============================================================

set -o pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT/logs"
REPORT_DIR="$ROOT/reports"
CONFIG_DIR="$ROOT/config"

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$CONFIG_DIR"

# High-contrast 256-color palette for LIGHT terminal backgrounds.
# Keep the existing color variable names to preserve all dashboard methods.
RED='\033[1;38;5;160m'      # Deep crimson: critical / errors
GREEN='\033[1;38;5;28m'     # Forest green: success / information
YELLOW='\033[1;38;5;130m'   # Dark amber: warnings (not bright yellow)
BLUE='\033[1;38;5;25m'      # Deep blue: dividers
PURPLE='\033[1;38;5;90m'    # Dark violet: debug
CYAN='\033[1;38;5;30m'      # Dark teal: headings / menu choices
WHITE='\033[1;38;5;235m'    # Near-black: headings on white
DIM='\033[38;5;242m'       # Readable grey, not faint ANSI dim
RESET='\033[0m'

# Make grep --color=always matches readable on a light background.
# Only presentation is changed; search patterns and results stay the same.
export GREP_COLORS='ms=1;38;5;160;48;5;224:mc=1;38;5;160;48;5;224:fn=38;5;25:ln=1;38;5;30:se=38;5;242'

CURRENT_LOG=""
REFRESH_RATE=3

cleanup() {
    printf '\033[?25h\033[0m'
}
trap cleanup EXIT

pause() {
    printf '\n'
    read -r -p "Press Enter to continue..." _
}

clear_screen() {
    clear
}

line() {
    printf "${BLUE}%s${RESET}\n" \
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

header() {
    clear_screen

    printf "${CYAN}"
    cat <<'EOF'
   __    ____   ___   ____  __  __ __    _____ ____
  / /   / __ \ / __\ / __ \/ / / // /   / ___// __ \
 / /___/ /_/ // /_  / /_/ / /_/ // /___/ /__ / /_/ /
/_____/\____/ \___/ / .___/\____//_____/\___/ .___/
                    /_/                     /_/

EOF
    printf "${RESET}"

    printf "${WHITE}       LOGPULSE | SECURITY & LOG ANALYTICS${RESET}\n"
    printf "${DIM}       Bash-powered monitoring dashboard${RESET}\n\n"

    line
    printf "  ${GREEN}● SYSTEM ONLINE${RESET}"
    printf "   ${CYAN}%s${RESET}\n" "$(date '+%d %b %Y | %H:%M:%S')"

    printf "  ${DIM}HOST:${RESET} %s" "$(hostname)"
    printf "   ${DIM}USER:${RESET} %s\n" "$(whoami)"

    if [[ -n "$CURRENT_LOG" ]]; then
        printf "  ${DIM}ACTIVE LOG:${RESET} %s\n" \
            "${CURRENT_LOG#"$ROOT"/}"
    else
        printf "  ${YELLOW}No active log selected${RESET}\n"
    fi

    line
    printf '\n'
}

valid_log() {
    [[ -n "$CURRENT_LOG" && -f "$CURRENT_LOG" && -r "$CURRENT_LOG" ]]
}

require_log() {
    if ! valid_log; then
        printf "${YELLOW}Select a readable log file first.${RESET}\n"
        pause
        return 1
    fi
    return 0
}

log_count() {
    find "$LOG_DIR" -type f \
        \( -name '*.log' -o -name '*.txt' \) \
        -print | wc -l
}

select_log() {
    header
    printf "${CYAN}SELECT LOG FILE${RESET}\n\n"

    mapfile -d '' FILES < <(
        find "$LOG_DIR" -type f \
            \( -name '*.log' -o -name '*.txt' \) \
            -print0 | sort -z
    )

    if (( ${#FILES[@]} == 0 )); then
        printf "${YELLOW}No log files found.${RESET}\n"
        printf "Place .log or .txt files inside logs/\n"
        pause
        return
    fi

    local i=1
    for file in "${FILES[@]}"; do
        printf "  ${CYAN}%2d${RESET}  %s\n" \
            "$i" "${file#"$ROOT"/}"
        ((i++))
    done

    printf '\n'
    read -r -p "Select file number: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] &&
       (( choice >= 1 && choice <= ${#FILES[@]} )); then
        CURRENT_LOG="${FILES[choice-1]}"
        printf "${GREEN}Selected: %s${RESET}\n" "$CURRENT_LOG"
    else
        printf "${RED}Invalid selection.${RESET}\n"
    fi

    pause
}

severity_counts() {
    awk '
    BEGIN {
        error=0; warn=0; info=0; debug=0; critical=0
    }
    {
        s=toupper($0)

        if (s ~ /CRITICAL|FATAL|EMERGENCY|PANIC/)
            critical++
        else if (s ~ /ERROR|FAILED|FAILURE|EXCEPTION/)
            error++
        else if (s ~ /WARN|WARNING/)
            warn++
        else if (s ~ /DEBUG|TRACE/)
            debug++
        else
            info++
    }
    END {
        printf "%d %d %d %d %d\n",critical,error,warn,info,debug
    }' "$CURRENT_LOG"
}

bar() {
    local value="${1:-0}"
    local maximum="${2:-1}"
    local color="$3"
    local blocks=0

    (( maximum > 0 )) &&
        blocks=$(( value * 30 / maximum ))

    (( blocks > 30 )) && blocks=30

    printf '%b' "$color"

    for ((i=0; i<blocks; i++)); do
        printf '█'
    done

    printf '%b' "$RESET"
}

dashboard() {
    require_log || return
    header

    local total critical error warn info debug max

    total=$(wc -l < "$CURRENT_LOG")
    read -r critical error warn info debug < <(severity_counts)

    max=$total
    (( max == 0 )) && max=1

    printf "${WHITE}ANALYTICS OVERVIEW${RESET}\n\n"

    printf "  ${CYAN}TOTAL EVENTS${RESET}      %s\n" "$total"
    printf "  ${RED}CRITICAL${RESET}          %s\n" "$critical"
    printf "  ${RED}ERRORS${RESET}            %s\n" "$error"
    printf "  ${YELLOW}WARNINGS${RESET}          %s\n" "$warn"
    printf "  ${GREEN}OTHER / INFO${RESET}      %s\n" "$info"
    printf "  ${PURPLE}DEBUG${RESET}             %s\n" "$debug"

    printf '\n'
    line
    printf "${WHITE}EVENT DISTRIBUTION${RESET}\n\n"

    printf "  CRITICAL  "
    bar "$critical" "$max" "$RED"
    printf " %s\n" "$critical"

    printf "  ERROR     "
    bar "$error" "$max" "$RED"
    printf " %s\n" "$error"

    printf "  WARNING   "
    bar "$warn" "$max" "$YELLOW"
    printf " %s\n" "$warn"

    printf "  INFO      "
    bar "$info" "$max" "$GREEN"
    printf " %s\n" "$info"

    printf "  DEBUG     "
    bar "$debug" "$max" "$PURPLE"
    printf " %s\n" "$debug"

    printf '\n'
    line
    printf "${WHITE}SECURITY ASSESSMENT${RESET}\n\n"

    if (( critical > 0 )); then
        printf "  ${RED}HIGH RISK - Critical log events detected${RESET}\n"
    elif (( error > 10 )); then
        printf "  ${YELLOW}ELEVATED - Multiple errors detected${RESET}\n"
    elif (( error > 0 || warn > 0 )); then
        printf "  ${YELLOW}ATTENTION - Review flagged events${RESET}\n"
    else
        printf "  ${GREEN}NO SEVERITY ALERTS DETECTED${RESET}\n"
    fi

    printf '\n'
    printf "${DIM}Assessment is based on keyword counts only.${RESET}\n"
    pause
}

colorize() {
    awk '
    {
        s=toupper($0)
        if (s ~ /CRITICAL|FATAL|ERROR|FAILED|EXCEPTION/)
            print "\033[1;38;5;160m" $0 "\033[0m"
        else if (s ~ /WARN/)
            print "\033[1;38;5;130m" $0 "\033[0m"
        else if (s ~ /INFO|SUCCESS/)
            print "\033[1;38;5;28m" $0 "\033[0m"
        else if (s ~ /DEBUG/)
            print "\033[1;38;5;90m" $0 "\033[0m"
        else
            print $0
    }'
}

view_logs() {
    require_log || return
    header

    printf "${CYAN}RECENT LOG EVENTS${RESET}\n\n"
    tail -n 40 "$CURRENT_LOG" | colorize
    pause
}

search_logs() {
    require_log || return
    header

    printf "${CYAN}SEARCH LOG EVENTS${RESET}\n\n"
    read -r -p "Enter keyword or pattern: " term

    [[ -z "$term" ]] && return

    printf '\n'
    grep -inF --color=always -- "$term" "$CURRENT_LOG" |
        head -n 100 || true

    printf '\n'
    pause
}

filter_severity() {
    require_log || return
    header

    printf "${CYAN}FILTER LOG SEVERITY${RESET}\n\n"
    printf "  1. Critical\n"
    printf "  2. Error\n"
    printf "  3. Warning\n"
    printf "  4. Debug\n"
    printf "  5. Authentication failures\n\n"

    read -r -p "Select filter: " choice

    local pattern

    case "$choice" in
        1) pattern='CRITICAL|FATAL|EMERGENCY|PANIC' ;;
        2) pattern='ERROR|FAILED|FAILURE|EXCEPTION' ;;
        3) pattern='WARN|WARNING' ;;
        4) pattern='DEBUG|TRACE' ;;
        5) pattern='FAILED PASSWORD|AUTHENTICATION FAILURE|INVALID USER|LOGIN FAILED' ;;
        *) return ;;
    esac

    printf '\n'
    grep -inEi --color=always \
        -- "$pattern" "$CURRENT_LOG" |
        head -n 100 || true

    pause
}

live_monitor() {
    require_log || return
    header

    printf "${GREEN}● LIVE LOG MONITORING${RESET}\n"
    printf "${DIM}Press Ctrl+C to stop live monitoring.${RESET}\n\n"

    tail -n 15 -f "$CURRENT_LOG"
}

top_events() {
    require_log || return
    header

    printf "${CYAN}TOP REPEATED LOG EVENTS${RESET}\n\n"

    sed -E \
        -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9:.+-]+[[:space:]]*//' \
        -e 's/^[A-Z][a-z]{2}[[:space:]]+[ 0-9][0-9][[:space:]]+[0-9:]{8}[[:space:]]*//' \
        "$CURRENT_LOG" |
        sort |
        uniq -c |
        sort -nr |
        head -n 15

    pause
}

export_report() {
    require_log || return
    header

    local filename total critical error warn info debug
    filename="$REPORT_DIR/report_$(date +%Y%m%d_%H%M%S).txt"

    total=$(wc -l < "$CURRENT_LOG")
    read -r critical error warn info debug < <(severity_counts)

    {
        echo "=========================================="
        echo "         LOGPULSE ANALYTICS REPORT"
        echo "=========================================="
        echo "Generated : $(date)"
        echo "Host      : $(hostname)"
        echo "Log       : $CURRENT_LOG"
        echo
        echo "TOTAL EVENTS : $total"
        echo "CRITICAL     : $critical"
        echo "ERRORS       : $error"
        echo "WARNINGS     : $warn"
        echo "INFO / OTHER : $info"
        echo "DEBUG        : $debug"
        echo
        echo "=========================================="
        echo "RECENT ERRORS"
        echo "=========================================="
        grep -iE 'ERROR|FAILED|FATAL|CRITICAL' \
            "$CURRENT_LOG" | tail -n 30 || true
        echo
        echo "=========================================="
        echo "TOP REPEATED EVENTS"
        echo "=========================================="
        sort "$CURRENT_LOG" | uniq -c | sort -nr | head -n 10
    } > "$filename"

    printf "${GREEN}Report generated successfully!${RESET}\n\n"
    printf "  %s\n" "$filename"
    pause
}

system_monitor() {
    header
    printf "${CYAN}SYSTEM PERFORMANCE MONITOR${RESET}\n\n"

    printf "${WHITE}UPTIME${RESET}\n"
    uptime
    printf '\n'

    printf "${WHITE}MEMORY USAGE${RESET}\n"
    free -h
    printf '\n'

    printf "${WHITE}DISK USAGE${RESET}\n"
    df -h "$ROOT"
    printf '\n'

    printf "${WHITE}TOP CPU PROCESSES${RESET}\n"
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 11

    pause
}

security_monitor() {
    require_log || return
    header

    printf "${RED}SECURITY EVENT MONITOR${RESET}\n\n"

    printf "${YELLOW}Authentication failures:${RESET}\n"
    grep -icE \
        'failed password|authentication failure|invalid user|login failed' \
        "$CURRENT_LOG" || true

    printf '\n'
    printf "${YELLOW}Permission denied events:${RESET}\n"
    grep -ic 'permission denied' "$CURRENT_LOG" || true

    printf '\n'
    printf "${YELLOW}Suspicious keywords:${RESET}\n"
    grep -inEi \
        'unauthorized|intrusion|brute.?force|suspicious|attack|denied' \
        "$CURRENT_LOG" | head -n 30 || true

    printf '\n'
    printf "${DIM}Keyword matches are indicators, not proof of an attack.${RESET}\n"

    pause
}

generate_demo() {
    header

    local file="$LOG_DIR/demo_$(date +%Y%m%d_%H%M%S).log"
    local levels=(INFO INFO INFO DEBUG WARNING ERROR CRITICAL)
    local messages=(
        "HTTP request completed"
        "User session created"
        "Database connection established"
        "API response received"
        "Cache refreshed"
        "High memory utilization detected"
        "Authentication failed for invalid user"
        "Application worker restarted"
        "Permission denied while accessing resource"
        "Connection timeout from remote endpoint"
        "Background task completed"
        "Unexpected exception in service"
        "Disk usage threshold exceeded"
        "Login successful"
        "Unauthorized access attempt detected"
    )

    for ((i=0; i<350; i++)); do
        level="${levels[RANDOM % ${#levels[@]}]}"
        message="${messages[RANDOM % ${#messages[@]}]}"

        printf '%s [%s] %s | pid=%d\n' \
            "$(date -d "-$((350-i)) minutes" '+%Y-%m-%d %H:%M:%S')" \
            "$level" "$message" "$((1000 + RANDOM % 8000))"
    done > "$file"

    CURRENT_LOG="$file"

    printf "${GREEN}Demo dataset generated.${RESET}\n"
    printf "350 simulated log events created.\n"
    printf "Active log: %s\n" "$file"

    pause
}

import_log() {
    header
    printf "${CYAN}IMPORT LOG FILE${RESET}\n\n"

    read -r -p "Enter absolute or relative log file path: " source

    if [[ ! -f "$source" || ! -r "$source" ]]; then
        printf "${RED}File not found or not readable.${RESET}\n"
        pause
        return
    fi

    local destination
    destination="$LOG_DIR/import_$(date +%Y%m%d_%H%M%S)_$$.log"

    if cp -- "$source" "$destination"; then
        CURRENT_LOG="$destination"
        printf "${GREEN}Log imported successfully.${RESET}\n"
    else
        printf "${RED}Import failed.${RESET}\n"
    fi

    pause
}

run_existing_analyzer() {
    header

    if [[ -f "$ROOT/analyzer.sh" ]]; then
        printf "${CYAN}RUNNING EXISTING PROJECT ANALYZER${RESET}\n\n"
        (
            cd "$ROOT" || exit 1
            bash analyzer.sh
        )
    else
        printf "${RED}analyzer.sh not found.${RESET}\n"
    fi

    pause
}

settings() {
    header
    printf "${CYAN}DASHBOARD SETTINGS${RESET}\n\n"
    printf "Current refresh rate: %s seconds\n\n" "$REFRESH_RATE"

    read -r -p "New refresh rate (1-30): " value

    if [[ "$value" =~ ^[0-9]+$ ]] &&
       (( value >= 1 && value <= 30 )); then
        REFRESH_RATE="$value"
        printf "${GREEN}Setting updated.${RESET}\n"
    else
        printf "${YELLOW}Setting unchanged.${RESET}\n"
    fi

    pause
}

auto_dashboard() {
    require_log || return

    while true; do
        header

        local total errors warnings critical
        total=$(wc -l < "$CURRENT_LOG")

        errors=$(grep -icE 'ERROR|FAILED|EXCEPTION' \
            "$CURRENT_LOG" || true)
        warnings=$(grep -icE 'WARN|WARNING' \
            "$CURRENT_LOG" || true)
        critical=$(grep -icE 'CRITICAL|FATAL' \
            "$CURRENT_LOG" || true)

        printf "${WHITE}AUTO-REFRESH MONITOR${RESET}\n\n"
        printf "  TOTAL EVENTS   : ${CYAN}%s${RESET}\n" "$total"
        printf "  ERRORS         : ${RED}%s${RESET}\n" "$errors"
        printf "  WARNINGS       : ${YELLOW}%s${RESET}\n" "$warnings"
        printf "  CRITICAL       : ${RED}%s${RESET}\n" "$critical"

        printf '\n'
        line

        printf "${CYAN}LATEST EVENTS${RESET}\n\n"
        tail -n 12 "$CURRENT_LOG" | colorize

        printf '\n'
        printf "${DIM}Refreshing every %ss. Press Ctrl+C to exit.${RESET}\n" \
            "$REFRESH_RATE"

        sleep "$REFRESH_RATE"
    done
}

main_menu() {
    while true; do
        header

        printf "${WHITE}MAIN DASHBOARD${RESET}\n\n"

        printf "  ${CYAN}[01]${RESET}  Analytics Overview\n"
        printf "  ${CYAN}[02]${RESET}  Select Log File\n"
        printf "  ${CYAN}[03]${RESET}  View Recent Logs\n"
        printf "  ${CYAN}[04]${RESET}  Search Log Events\n"
        printf "  ${CYAN}[05]${RESET}  Filter by Severity\n"
        printf "  ${CYAN}[06]${RESET}  Live Log Streaming\n"
        printf "  ${CYAN}[07]${RESET}  Top Repeated Events\n"
        printf "  ${CYAN}[08]${RESET}  Export Analytics Report\n"
        printf "  ${CYAN}[09]${RESET}  System Performance\n"
        printf "  ${CYAN}[10]${RESET}  Security Event Monitor\n"
        printf "  ${CYAN}[11]${RESET}  Generate Demo Logs\n"
        printf "  ${CYAN}[12]${RESET}  Import External Logs\n"
        printf "  ${CYAN}[13]${RESET}  Run Existing Analyzer\n"
        printf "  ${CYAN}[14]${RESET}  Dashboard Settings\n"
        printf "  ${CYAN}[15]${RESET}  Auto-Refresh Dashboard\n"
        printf "  ${RED}[00]${RESET}  Exit\n"

        printf '\n'
        line

        printf "  ${GREEN}Log files available: %s${RESET}\n" \
            "$(log_count)"

        printf '\n'
        read -r -p "  logpulse > " choice || break

        case "$choice" in
            1|01) dashboard ;;
            2|02) select_log ;;
            3|03) view_logs ;;
            4|04) search_logs ;;
            5|05) filter_severity ;;
            6|06) live_monitor ;;
            7|07) top_events ;;
            8|08) export_report ;;
            9|09) system_monitor ;;
            10) security_monitor ;;
            11) generate_demo ;;
            12) import_log ;;
            13) run_existing_analyzer ;;
            14) settings ;;
            15) auto_dashboard ;;
            0|00)
                clear
                printf "${GREEN}Thank you for using LogPulse!${RESET}\n"
                exit 0
                ;;
            *)
                printf "${RED}Invalid option.${RESET}\n"
                sleep 1
                ;;
        esac
    done
}

main_menu
