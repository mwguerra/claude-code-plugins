#!/usr/bin/env bash
# Drain the notifications table — dispatch all status='pending' rows to their
# configured target. Called by /e2e-test-specialist:notify --send and by the
# autopilot's completion step.
#
# Targets supported (per-row .target overrides .config.notifications.default_target):
#   file:<path>          → append a JSON line to the file (created if missing)
#   webhook:<url>        → POST JSON {id,kind,severity,title,body,related_run,sent_at}
#   notify:              → osascript on macOS / notify-send on Linux
#   (empty / unknown)    → fall back to file:.e2e-testing/logs/notifications.log
#
# config.notifications.min_severity_for_webhook: 'info' | 'warning' | 'critical'
#   notifications below this threshold dispatch via file/notify only,
#   never the webhook.

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?}/scripts/lib.sh"
e2e_require_db

DEFAULT_TARGET="$(e2e_config_get notifications.default_target "file:$E2E_ROOT_DIR/logs/notifications.log")"
WEBHOOK_URL="$(e2e_config_get notifications.webhook_url "")"
MIN_SEV_WH="$(e2e_config_get notifications.min_severity_for_webhook "warning")"

sev_rank() {
    case "$1" in info) echo 1 ;; warning) echo 2 ;; critical) echo 3 ;; *) echo 0 ;; esac
}
MIN_RANK="$(sev_rank "$MIN_SEV_WH")"

# Pull pending rows as TSV — one record per line, fields tab-separated.
# Use COALESCE for nullable columns to avoid empty-field misalignment.
PENDING="$(sqlite3 -bail -separator $'\t' "$E2E_DB" "
  SELECT id, kind, severity, title, COALESCE(body,''),
         COALESCE(related_run,''), COALESCE(target,'')
    FROM notifications
   WHERE status='pending'
   ORDER BY created_at ASC;
")"

if [[ -z "$PENDING" ]]; then
    echo "notify.sh: no pending notifications"
    exit 0
fi

SENT=0; FAILED=0
while IFS=$'\t' read -r ID KIND SEV TITLE BODY RUN TARGET; do
    [[ -n "$ID" ]] || continue
    DEST="${TARGET:-$DEFAULT_TARGET}"

    JSON_PAYLOAD="$(jq -n \
        --arg id "$ID" --arg kind "$KIND" --arg severity "$SEV" \
        --arg title "$TITLE" --arg body "$BODY" --arg run "$RUN" \
        --arg sent_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{id:$id, kind:$kind, severity:$severity, title:$title, body:$body, related_run:$run, sent_at:$sent_at}' 2>/dev/null \
      || printf '{"id":"%s","kind":"%s","severity":"%s","title":"%s","sent_at":"%s"}\n' \
                "$ID" "$KIND" "$SEV" "$TITLE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"

    case "$DEST" in
        file:*)
            FILE="${DEST#file:}"
            mkdir -p "$(dirname "$FILE")"
            printf '%s\n' "$JSON_PAYLOAD" >> "$FILE"
            STATUS="sent"
            ;;
        webhook:*)
            URL="${DEST#webhook:}"
            if [[ "$(sev_rank "$SEV")" -lt "$MIN_RANK" ]]; then
                STATUS="suppressed"
            elif command -v curl >/dev/null 2>&1; then
                if curl -fsS -X POST -H 'content-type: application/json' \
                        --data "$JSON_PAYLOAD" "$URL" >/dev/null; then
                    STATUS="sent"
                else
                    STATUS="failed"
                fi
            else
                STATUS="failed"
            fi
            ;;
        notify:*)
            if [[ "$(uname)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
                osascript -e "display notification \"$BODY\" with title \"$TITLE\" subtitle \"$KIND ($SEV)\"" >/dev/null 2>&1 \
                    && STATUS="sent" || STATUS="failed"
            elif command -v notify-send >/dev/null 2>&1; then
                notify-send "$TITLE" "$BODY" && STATUS="sent" || STATUS="failed"
            else
                STATUS="failed"
            fi
            ;;
        *)
            # Unknown target → fall back to default file
            FILE="$E2E_ROOT_DIR/logs/notifications.log"
            mkdir -p "$(dirname "$FILE")"
            printf '%s\n' "$JSON_PAYLOAD" >> "$FILE"
            STATUS="sent"
            ;;
    esac

    sqlite3 "$E2E_DB" "
        UPDATE notifications
           SET status='$STATUS',
               sent_at=datetime('now'),
               target=$(e2e_sql_quote "$DEST")
         WHERE id=$(e2e_sql_quote "$ID");
    "
    case "$STATUS" in
        sent|suppressed) SENT=$((SENT+1)) ;;
        failed)          FAILED=$((FAILED+1)) ;;
    esac
done <<< "$PENDING"

echo "notify.sh: $SENT dispatched, $FAILED failed"
[[ "$FAILED" -eq 0 ]]
