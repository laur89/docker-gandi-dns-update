#!/usr/bin/env bash
#
readonly API_HEAD='https://dns.api.gandi.net/api/v5/domains'
readonly LAST_KNOWN_IP_FILE='/tmp/.last_known_ip.tmp'


update_records() {
    local record c_rec r target

    if [[ "$OVERWRITE" == true ]]; then
        echo "deleting existing records..."
        curl "${CURL_FLAGS[@]}" -X DELETE \
               "$API_HEAD/$DOMAIN/records" || fail "deleting records for [$DOMAIN] failed with $?"
    fi

    if [[ -n "$A_RECORDS" ]]; then
        for record in $A_RECORDS; do
            update_record "$(create_record "$IP")" "$record" A
        done
    fi

    # note CNAME records are only pushed if ALWAYS_PUBLISH_CNAME=true:
    if [[ "$ALWAYS_PUBLISH_CNAME" == true && -n "$C_RECORDS" ]]; then
        readarray -t -d ';' c_rec <<< "$C_RECORDS"
        for r in "${c_rec[@]}"; do
            read -ra r <<< "$r"
            [[ "${#r[@]}" -lt 2 ]] && fail "CNAME record config needs to contain at least 2 elements - source & target"
            target="${r[-1]}"
            unset r[-1]  # pop the target
            # check for dot: (https://docs.dnscontrol.org/language-reference/why-the-dot)
            [[ "$target" == *.* && "$target" != *. ]] && fail "ambiguous target [$target]; forgot to add a dot to the end?"

            for record in "${r[@]}"; do
                update_record "$(create_record "$target")" "$record" CNAME
            done
        done
    fi
}

update_record() {
    local record name type

    record="$1"
    name="$2"
    type="$3"

    echo "updating record [${name}-${type}]..."
    curl "${CURL_FLAGS[@]}" -X PUT -d "$record" \
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

    readonly timeout=2  # in sec

    # TODO: dns queries not working in some cases (some routers heck it up?)
    ip="$(dig +short +timeout=$timeout @resolver1.opendns.com myip.opendns.com 2>/dev/null)"
    [[ $? -eq 0 && -n "$ip" ]] && is_valid_ip "$ip" && { echo "$ip"; return 0; }

    # couldn't resolve via dig, try other services...
    for url in \
            'https://diagnostic.opendns.com/myip' \
            'http://whatismyip.akamai.com' \
            'https://checkip.amazonaws.com' \
            'https://api.ipify.org' \
            'https://icanhazip.com/' \
            'https://ipecho.net/plain' \
            'https://ipinfo.io/ip' \
                ; do
        ip="$(curl --fail --max-time "$timeout" --connect-timeout 1 -s "$url")" && \
            [[ -n "$ip" ]] && is_valid_ip "$ip" && break
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


# Checks whether given IP is a valid ipv4.
# from https://stackoverflow.com/a/13777424
#
# @param {string}  ip   ip which validity to test.
#
# @returns {bool}  true, if provided IP was a valid ipv4.
is_valid_ip() {
    local ip

    ip="$1"

    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        readarray -t -d '.' ip <<< "$ip"

        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        return $?
    fi

    return 1
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

if [[ "$prev_ip" == "$IP" ]]; then
    if [[ "$PUBLISH_ONLY_ON_IP_CHANGE" == true ]]; then
        echo "ip unchanged & PUBLISH_ONLY_ON_IP_CHANGE==true, skipping update"
        exit 0
    fi

    echo "ip unchanged, but PUBLISH_ONLY_ON_IP_CHANGE==false - updating records..."
else
    echo "new IP: [$IP], updating records..."
fi

# curl flags used when querying gandi api:
CURL_FLAGS=(
    -w '\n'
    --max-time 4
    --connect-timeout 2
    --retry 1
    -H 'Content-Type: application/json'
    -H "X-Api-Key: $API_KEY"
    -s -S --fail
)

update_records

[[ "$prev_ip" != "$IP" ]] && echo -n "$IP" > "$LAST_KNOWN_IP_FILE"  # only store if update has succeeded!
exit 0
