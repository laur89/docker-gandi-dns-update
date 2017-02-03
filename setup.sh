#!/bin/bash
#
# installs cron file executing gad script at required interval;
# also runs gad once, so it'd be always done first thing during container startup.

readonly CRONFILE_TEMPLATE='/cron.template'
readonly CRONFILE='/etc/cron.d/gad.cron'
readonly DEFAULT_CRON_PATTERN='*/15 * * * *'
readonly LOGFILE='/var/log/gad.log'
readonly GAD_CMD_HEAD="gad -a $API_KEY -d $ZONE -r"


validate_config() {
    [[ -z "$API_KEY" ]] && fail "API_KEY env var is missing"
    [[ -z "$RECORD" ]] && fail "RECORD env var is missing"
    [[ "$ZONE" =~ ^[a-z]+\.[a-z]+$ ]] || fail "ZONE env var appears to be in unexpected format: [$ZONE]"
}


check_dependencies() {
    local i

    for i in dig gad; do
        command -v "$i" >/dev/null || fail "[$i] not installed"
    done
}


setup_cron() {
    # copy new template over previous cronfile:
    cp -- "$CRONFILE_TEMPLATE" "$CRONFILE" || fail "copying cron template failed"

    # add cron entry:
    printf '%s  root  %s "%s" >> "%s"' "${CRON_PATTERN:-"$DEFAULT_CRON_PATTERN"}" "$GAD_CMD_HEAD" "$RECORD" "$LOGFILE" >> "$CRONFILE"
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
$GAD_CMD_HEAD "$RECORD" >> "$LOGFILE" || handle_startup_failure "$?"

exit 0