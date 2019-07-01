#!/bin/bash
#
readonly API_HEAD='https://dns.api.gandi.net/api/v5/domains'
readonly LAST_KNOWN_IP_FILE='/tmp/.last_known_ip.tmp'


update_records() {
    local record c_rec r target

    if [[ "$OVERWRITE" == true ]]; then
        curl --fail -X DELETE -H 'Content-Type: application/json' \
               -H "X-Api-Key: $API_KEY" \
               "$API_HEAD/$DOMAIN/records" || fail "deleting records for [$DOMAIN] failed with $?"
    fi

    if [[ -n "$A_RECORDS" ]]; then
        for record in $A_RECORDS; do
            update_record "$(create_record "$IP")" "$record" A
        done
    fi

    # note CNAME records are only pushed if ALWAYS_PUBLISH_CNAME=true:
    if [[ "$ALWAYS_PUBLISH_CNAME" == true && -n "$C_RECORDS" ]]; then
        while IFS=';' read -ra c_rec; do
            for r in "${c_rec[@]}"; do
                read -ra r <<< "$r"
                [[ "${#r[@]}" -lt 2 ]] && fail "CNAME record config needs to contain at least 2 elements - source & target"
                target="${r[-1]}"
                unset r[-1]
                # check for dot: (https://stackexchange.github.io/dnscontrol/why-the-dot)
                [[ "$target" == *.* && "$target" != *. ]] && fail "ambiguous target [$target]; forgot to add a dot to the end?"

                for record in "${r[@]}"; do
                    update_record "$(create_record "$target")" "$record" CNAME
                done
            done
        done <<< "$C_RECORDS"
    fi
}

update_record() {
    local record name type

    record="$1"
    name="$2"
    type="$3"

    curl --fail -X PUT -H 'Content-Type: application/json' \
        -H "X-Api-Key: $API_KEY" \
        -d "$record" \
        "$API_HEAD/$DOMAIN/records/$name/$type" || fail "pushing record update for [${name}-${type}] failed with $?"
}

create_record() {
    local value

    value="$1"

    printf '{"rrset_ttl": %d,"rrset_values": ["%s"]}' "$TTL" "$value" || fail "printf failed with $?"
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
    local ip timeout url

    readonly timeout=1  # in sec

    # TODO: dns queries not working in some cases (some routers heck it up?)
    ip="$(dig @resolver1.opendns.com ANY myip.opendns.com +short +timeout=$timeout 2>/dev/null)"
    [[ $? -eq 0 && -n "$ip" ]] && { echo "$ip"; return 0; }

    # couldn't resolve via dig, try other services...
    for url in \
            'http://whatismyip.akamai.com' \
            'https://api.ipify.org' \
            'http://icanhazip.com' \
            'https://diagnostic.opendns.com/myip'; do
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
while getopts "k:d:a:c:t:O:I:F:" opt; do
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
        O)
            OVERWRITE="$OPTARG"
            ;;
        I)
            PUBLISH_ONLY_ON_IP_CHANGE="$OPTARG"
            ;;
        F)
            ALWAYS_PUBLISH_CNAME="$OPTARG"
            ;;
        *)
            fail "incorrect option passed"
            ;;
    esac
done

check_connection || fail "no connection, skipping"
[[ -s "$LAST_KNOWN_IP_FILE" ]] && prev_ip="$(cat -- "$LAST_KNOWN_IP_FILE")"
IP="$(get_external_ip)"

if [[ "$PUBLISH_ONLY_ON_IP_CHANGE" == true && "$prev_ip" == "$IP" ]]; then
    echo "ip unchanged & PUBLISH_ONLY_ON_IP_CHANGE==true, skipping"
    exit 0
fi

update_records

[[ "$prev_ip" != "$IP" ]] && echo -n "$IP" > "$LAST_KNOWN_IP_FILE"  # only store if update has succeeded
exit 0
