#!/bin/bash
#
# installs cron file executing gad script at required interval;
# also runs gad once, so it'd be always done first thing during container startup.

readonly CRONFILE_TEMPLATE='/cron.template'
readonly CRONFILE='/etc/cron.d/gad'
readonly DEFAULT_CRON_PATTERN='*/15 * * * *'
readonly LOGFILE='/var/log/gad.log'
readonly GAD_CMD="gad -a $API_KEY -d $ZONE -r \"$RECORD\""


validate_config() {
    [[ -z "$API_KEY" ]] && fail "API_KEY env var is missing"
    [[ -z "$RECORD" ]] && fail "RECORD env var is missing"
    [[ "$ZONE" =~ ^[a-zA-Z0-9]+\.[a-zA-Z0-9]+$ ]] || fail "ZONE env var appears to be in unexpected format: [$ZONE]"
}


check_dependencies() {
    local i

    for i in gad dig openssl; do
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
eval "$GAD_CMD" >> "$LOGFILE" || handle_startup_failure "$?"

exit 0
