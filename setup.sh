#!/bin/bash
#
# installs cron file executing gad script at required interval;
# also runs gad once, so it'd be always done first thing during container startup.

readonly CRONFILE_TEMPLATE='/cron.template'
readonly CRONFILE='/var/spool/cron/crontabs/root'
readonly DEFAULT_CRON_PATTERN='*/15 * * * *'
readonly DEFAULT_TTL=10800
readonly LOGFILE='/var/log/gad.log'
readonly GAD_CMD="/gad -k '$API_KEY' -d '$DOMAIN' -a '$A_RECORDS' \
  -c '$C_RECORDS' -t '${TTL:-$DEFAULT_TTL}' -O '${OVERWRITE:-false}' \
  -I '${PUBLISH_ONLY_ON_IP_CHANGE:-true}'"


validate_config() {
    [[ -z "$API_KEY" ]] && fail "API_KEY env var is missing"
    [[ -z "$A_RECORDS" && -z "$C_RECORDS" ]] && fail "both A_RECORDS and C_RECORDS env vars are missing"
    #[[ "$DOMAIN" =~ ^[a-zA-Z0-9]+\.[a-zA-Z0-9]+$ ]] || fail "DOMAIN env var appears to be in unexpected format: [$DOMAIN]"
    [[ -z "$DOMAIN" ]] && fail "DOMAIN env var cannot be empty"
    [[ -n "$TTL" ]] && ! [[ "$TTL" =~ ^[0-9]+$ && "$TTL" -gt 0 ]] && fail "TTL value, when given, needs to be a positive int"
    [[ -n "$ALWAYS_PUBLISH_CNAME" ]] && ! [[ "$ALWAYS_PUBLISH_CNAME" =~ ^(true|false)$ ]] && fail "ALWAYS_PUBLISH_CNAME value, when given, can be either [true] or [false]"
    [[ -n "$PUBLISH_ONLY_ON_IP_CHANGE" ]] && ! [[ "$PUBLISH_ONLY_ON_IP_CHANGE" =~ ^(true|false)$ ]] && fail "PUBLISH_ONLY_ON_IP_CHANGE value, when given, can be either [true] or [false]"
    [[ -n "$OVERWRITE" ]] && ! [[ "$OVERWRITE" =~ ^(true|false)$ ]] && fail "OVERWRITE value, when given, can be either [true] or [false]"

    [[ "$OVERWRITE" == true ]] && ALWAYS_PUBLISH_CNAME=true  # otherwise we'd lose CNAME records from 2nd run onwards;
}


check_dependencies() {
    local i

    for i in ping curl dig; do
        command -v "$i" >/dev/null || fail "[$i] not installed"
    done
}


setup_cron() {
    # copy new template over previous cronfile:
    cp -- "$CRONFILE_TEMPLATE" "$CRONFILE" || fail "copying cron template failed"

    # add cron entry:
    printf '%s  %s >> "%s" 2>&1\n' "${CRON_PATTERN:-"$DEFAULT_CRON_PATTERN"}" "$GAD_CMD -F '${ALWAYS_PUBLISH_CNAME:-false}'" "$LOGFILE" >> "$CRONFILE"
    # test entry:
    #printf '%s  %s >> "%s" 2>&1\n' "${CRON_PATTERN:-"$DEFAULT_CRON_PATTERN"}" 'echo "running cron @ $(date)"' "$LOGFILE" >> "$CRONFILE"

    # alternatively pipe crontab drectly into crontab without writing into directory:
    #printf '%s  %s >> "%s"\n' "${CRON_PATTERN:-"$DEFAULT_CRON_PATTERN"}" "$GAD_CMD -F '${ALWAYS_PUBLISH_CNAME:-false}'" "$LOGFILE" | crontab - || fail "calling crontab failed with $?"
}


handle_startup_failure() {
    local exit_code

    readonly exit_code="$1"

    echo -e "-> gad output:\n-------------------"
    cat -- "$LOGFILE"
    echo -e "-------------------"
    fail "gad startup execution failed with code [$exit_code]"
}


fail() {
    local msg
    readonly msg="$1"
    echo -e "\n\n    ERROR: $msg\n\n"
    exit 1
}


# ================
# Entry
# ================
validate_config
check_dependencies
setup_cron
# note for the first go, we force CNAME updates:
eval "$GAD_CMD -F true" >> "$LOGFILE" 2>&1 || handle_startup_failure "$?"

exit 0
