#!/bin/sh
set -e

# Create dedicated system user zohal if not exists
if ! id -u zohal >/dev/null 2>&1; then
    useradd -r -s /bin/false -d /var/lib/zohal -c "Zohal Service User" zohal || true
fi

# Reload systemd and enable service
if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
    systemctl enable zohald.service || true
fi

echo "Zohal Connect installed. / سرویس زحل با موفقیت نصب شد."
