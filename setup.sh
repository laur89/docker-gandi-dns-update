#!/bin/bash
#
# installs cron file executing gad script at required interval;
# also runs gad once, so it'd be always done first thing during container startup.

readonly CRONFILE_TEMPLATE='/cron.template'
readonly CRONFILE='/etc/cron.d/gad'
readonly DEFAULT_CRON_PATTERN='*/15 * * * *'
readonly LOGFILE='/var/log/gad.log'
readonly GAD_CMD="/gad -k $API_KEY -d $DOMAIN -a '$A_RECORDS' -c '$C_RECORDS' -F '$FORCE'"


validate_config() {
    [[ -z "$API_KEY" ]] && fail "API_KEY env var is missing"
    [[ -z "$A_RECORDS" && -z "$C_RECORDS" ]] && fail "both A_RECORDS and C_RECORDS env vars are missing"
    [[ "$DOMAIN" =~ ^[a-zA-Z0-9]+\.[a-zA-Z0-9]+$ ]] || fail "DOMAIN env var appears to be in unexpected format: [$DOMAIN]"
    [[ -n "$FORCE" ]] && ! [[ "$FORCE" =~ ^(true|false)$ ]] && fail "FORCE value, when given, can be either [true] or [false]"
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
    printf '%s  root  %s >> "%s"\n' "${CRON_PATTERN:-"$DEFAULT_CRON_PATTERN"}" "$GAD_CMD" "$LOGFILE" >> "$CRONFILE"
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
# note for the first go, we force it:
eval "$GAD_CMD -F true" >> "$LOGFILE" || handle_startup_failure "$?"

exit 0
