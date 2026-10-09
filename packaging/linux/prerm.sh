#!/bin/sh
set -e

if [ -d /run/systemd/system ]; then
    systemctl stop zohald.service || true
    systemctl disable zohald.service || true
fi

# Run cleanup to revert any routes or tunnel state
if [ -x /usr/lib/zohal/zohald ]; then
    /usr/lib/zohal/zohald cleanup || true
fi
