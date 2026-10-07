#!/usr/bin/env bash
# End-to-end scenarios for install-xroad-nftables.sh.
#
# Replaces /etc/nftables.conf and the active ruleset, so it refuses to run
# outside a disposable container. CI runs it in ubuntu:24.04 with
# --cap-add NET_ADMIN; nft rules then apply only to the container's own
# network namespace.

# check() evals its second argument later, so single-quoted $vars are intended
# and assignments like rc= are read inside those strings.
# shellcheck disable=SC2016,SC2034

set -uo pipefail

[ -f /.dockerenv ] || { echo "Refusing to run outside a container." >&2; exit 2; }

cd "$(dirname "$0")/.." || exit 2
I=./install-xroad-nftables.sh
VARS=/etc/nftables.d/xroad-variables.nft
fails=0

check() {
    if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fails=$((fails + 1)); fi
}
tables() { nft list tables 2>/dev/null | tr '\n' ' '; }
has_table() { tables | grep -q "inet $1 "; }
fill() { sed -i -E 's/"CHANGE_ME"/"eth0"/; s/^([[:space:]]*)CHANGE_ME$/\110.99.0.1/' "$VARS"; }

# The container has no systemd; record calls instead.
if ! command -v systemctl >/dev/null; then
    printf '#!/bin/sh\necho "systemctl $*" >> /tmp/systemctl.log\n' > /usr/local/bin/systemctl
    chmod +x /usr/local/bin/systemctl
fi

$I > /tmp/a.log 2>&1; rc=$?
check "A: template stops at placeholders" '[ $rc -eq 1 ] && grep -q "unresolved placeholders" /tmp/a.log'
check "A: file permissions 0755 / 0640" '[ "$(stat -c %a /etc/nftables.conf)$(stat -c %a $VARS)" = 755640 ]'
check "A: nothing applied" '[ -z "$(tables)" ]'

fill
$I > /tmp/b.log 2>&1; rc=$?
check "B: filled values validate" '[ $rc -eq 0 ] && grep -q "Validation passed" /tmp/b.log'
check "B: variables kept, not overwritten" 'grep -q "Keeping existing" /tmp/b.log && grep -q 10.99.0.1 $VARS'
check "B: nothing applied" '[ -z "$(tables)" ]'

$I --apply --timeout 3 < /dev/null > /tmp/c.log 2>&1; rc=$?
check "C: unconfirmed apply fails" '[ $rc -eq 1 ] && grep -q "not confirmed" /tmp/c.log'
check "C: previous (empty) ruleset restored" '[ -z "$(tables)" ]'

echo yes | $I --apply --timeout 5 > /tmp/d.log 2>&1; rc=$?
check "D: confirmed apply succeeds" '[ $rc -eq 0 ]'
check "D: xroad_filter active" 'has_table xroad_filter'
check "D: persistence enabled" 'grep -q "enable nftables" /tmp/systemctl.log'
sleep 6
check "D: cancelled rollback does not fire" 'has_table xroad_filter'

nft flush ruleset
nft add table inet before_marker
mkfifo /tmp/never
# Read-write open: a read-only open of a FIFO blocks until a writer appears.
$I --apply --timeout 6 <> /tmp/never > /tmp/e.log 2>&1 &
pid=$!
sleep 3
check "E: new ruleset live during confirmation" 'has_table xroad_filter'
kill -HUP "$pid"; wait "$pid" 2>/dev/null
sleep 7
check "E: lost session rolls back" 'has_table before_marker && ! has_table xroad_filter'

sed -i 's/tcp dport 22 /tcp dport 2222 /' /etc/nftables.conf
$I > /tmp/f.log 2>&1; rc=$?
check "F: changed policy is reported and replaced" '[ $rc -eq 0 ] && grep -q "^    -.*dport 2222" /tmp/f.log && ! grep -q "dport 2222" /etc/nftables.conf'
check "F: one backup directory per run" '[ "$(ls /var/backups/xroad-nftables | wc -l)" -eq 6 ]'

echo "$fails failure(s)"
[ "$fails" -eq 0 ]
