#!/usr/bin/env bash
# Verify e2e_redact masks credential values stored in the credentials table.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null
source "$CLAUDE_PLUGIN_ROOT/scripts/lib.sh"

# Seed a credential with secret values
sqlite3 "$E2E_DB" "
    INSERT INTO credentials (id, name, kind, fields)
    VALUES ('CRED-001', 'do-token', 'api-token',
            '{\"token\":\"dop_v1_supersecrettoken123\",\"host\":\"api.digitalocean.com\"}');
    INSERT INTO credentials (id, name, kind, fields)
    VALUES ('CRED-002', 'admin-creds', 'username-password',
            '{\"username\":\"admin\",\"password\":\"NotARealSecret_42!\"}');
"

# Build a sample report containing the secret values verbatim
cat <<'EOF' > /tmp/sample-report.txt
Connecting with token dop_v1_supersecrettoken123 to api.digitalocean.com
Logged in as admin with password NotARealSecret_42!
EOF

# Run redaction
redacted="$(e2e_redact < /tmp/sample-report.txt)"

# Token should be masked
echo "$redacted" | grep -q "dop_v1_supersecrettoken123" && {
    echo "token leaked through redaction:"
    echo "$redacted"
    exit 1
}

# Password should be masked
echo "$redacted" | grep -q "NotARealSecret_42!" && {
    echo "password leaked through redaction:"
    echo "$redacted"
    exit 1
}

# Host (k=host) should NOT be masked — non-secret field
echo "$redacted" | grep -q "api.digitalocean.com" || {
    echo "host was incorrectly redacted:"
    echo "$redacted"
    exit 1
}

# Redaction marker should be present for the credential
echo "$redacted" | grep -q "redacted:" || {
    echo "no redaction marker present:"
    echo "$redacted"
    exit 1
}
