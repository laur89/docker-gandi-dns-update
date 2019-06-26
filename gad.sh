#!/bin/bash
#
readonly LAST_KNOWN_IP_FILE='/tmp/.last_known_ip.tmp'


build_recors() {
    local records record c_rec r target

    declare -a records

    if [[ -n "$A_RECORDS" ]]; then
        for record in $A_RECORDS; do
            records+="$(create_record "$record" A "$TTL" "$IP")"
        done
    fi

    # note CNAME records are only pushed if force=true:
    if [[ "$FORCE" == true && -n "$C_RECORDS" ]]; then
        while IFS=';' read -ra c_rec; do
            for r in "${c_rec[@]}"; do
                read -a r <<< "$r"
                [[ "${#r[@]}" -lt 2 ]] && fail "CNAME record config needs to contain at least 2 elements - source & target"
                target="${r[-1]}"
                unset r[-1]

                for record in "${r[@]}"; do
                    records+="$(create_record "$record" CNAME "$TTL" "$target")"
                done
            done
        done <<< "$C_RECORDS"
    fi

    build_comma_separated_list "${records[@]}"
}

update_records() {
    local records

    records="$(build_recors)"
    curl --fail -X PUT -H 'Content-Type: application/json' \
        -H "X-Api-Key: $API_KEY" \
        -d "{\"items\": [$records]}" \
        "https://dns.api.gandi.net/api/v5/domains/$DOMAIN/records" || fail "pushing record updates failed with $?"
}

create_record() {
    local name type ttl values

    name="$1"
    type="$2"
    ttl="$3"
    values="$4"

    printf '{"rrset_name": "%s",
      "rrset_type": "%s",
      "rrset_ttl": %d,
      "rrset_values": ["%s"]}' "$name" "$type" "$ttl" "$values" || fail "printf failed with $?"
}


# Builds comma separated list.
#
# @param {string...}   list of elements to build string from.
#
# @returns {string}  comma separated list, eg "a,b,c"
build_comma_separated_list() {
    local element separator list
    readonly separator=','  # list separator

    # TODO: return empty string instead?
    [[ "$#" -eq 0 ]] && fail "args required"

    for element in "$@"; do
        list+="$element$separator"
    done

    echo "${list:0:$(( ${#list} - ${#separator} ))}"
    return 0
}

# Checks whether we have outside connection.
#
# @returns {bool}  0 if we have healthy connection to $ip
check_connection() {
    local ip timeout

    readonly ip='8.8.8.8'
    readonly timeout=2  # in seconds

    # Check whether the client is connected to the internet:
    #if wget --no-check-certificate -q --spider --timeout=$timeout -- "$ip" > /dev/null 2>&1; then  # works in networks where ping is not allowed
    if ping -W $timeout -c 1 -- "$ip" > /dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Finds our external IP address.
#
# @returns {string}  our external ip.
get_external_ip() {
    local ip timeout urls url

    readonly timeout=1  # in sec

    # TODO: dns queries not working in some cases (some routers heck it up?)
    ip="$(dig +short +time=$timeout myip.opendns.com @resolver1.opendns.com 2>/dev/null)" || {
        fail "problems resolving our external ip with dig."
    }

    [[ $? -eq 0 && -n "$ip" ]] && { echo "$ip"; return 0; }

    # couldn't resolve via dig, try other services...
    declare -a urls=(
        'http://whatismyip.akamai.com/'
        'https://api.ipify.org'
        'icanhazip.com'
    )

    for url in "${urls[@]}"; do
        ip="$(curl --fail -s "$url")" && [[ -n "$ip" ]] && break
        unset ip
    done

    [[ -z "$ip" ]] && fail "unable to resolve our external ip via dig or curl."
    echo "$ip"
    return 0
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
while getopts "k:d:a:c:t:F:" opt; do
    case "$opt" in
        k)
            API_KEY="$OPTARG"
            ;;
        d)
            DOMAIN="$OPTARG"
            ;;
        a)
            A_RECORDS="$OPTARG"
            ;;
        c)
            C_RECORDS="$OPTARG"
            ;;
        t)
            TTL="$OPTARG"
            ;;
        F)
            FORCE="$OPTARG"
            ;;
        *)
            fail "icorrect option passed"
            ;;
    esac
done

check_connection || fail "no connection, skipping"
[[ -s "$LAST_KNOWN_IP_FILE" ]] && prev_ip="$(cat -- "$LAST_KNOWN_IP_FILE")"
IP="$(get_external_ip)"

if [[ "$FORCE" != true && "$prev_ip" == "$IP" ]]; then
    echo "ip unchanged & force!=true, skipping"
    exit 0
fi

update_records

[[ "$prev_ip" != "$IP" ]] && echo -n "$IP" > "$LAST_KNOWN_IP_FILE"  # only store if update has succeeded
exit 0
