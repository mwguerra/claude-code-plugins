#!/bin/bash
# Secretary Plugin - AI Multi-Item Extractor
# Single AI call per queue item (not 3 like my-workflow)
# Uses Claude CLI or Anthropic API with pattern-based fallback
#
# Cross-platform: Linux, macOS, Windows/Git Bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"
source "$PLUGIN_ROOT/hooks/scripts/lib/db.sh"

# ============================================================================
# Configuration
# ============================================================================

AI_MODEL="${SECRETARY_AI_MODEL:-haiku}"
AI_MAX_TOKENS=1000
AI_TIMEOUT=20
AI_MAX_BUDGET="0.50"

# ============================================================================
# AI Availability
# ============================================================================

extractor_cli_available() {
    command -v claude >/dev/null 2>&1
}

extractor_ai_enabled() {
    local enabled
    enabled=$(get_config '.ai.enabled' 'true')
    if [[ "$enabled" != "true" ]]; then
        return 1
    fi
    if extractor_cli_available; then return 0; fi
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then return 0; fi
    debug_log "AI extraction disabled: no Claude CLI or ANTHROPIC_API_KEY"
    return 1
}

extractor_get_method() {
    if extractor_cli_available; then echo "cli"
    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then echo "api"
    else echo "none"
    fi
}

# ============================================================================
# Multi-Item Extraction (1 call per item)
# ============================================================================

ai_extract_all_items() {
    local text="$1"

    if ! extractor_ai_enabled; then
        echo '{"error": "ai_disabled", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi

    # Truncate
    local max_chars=3000
    if [[ ${#text} -gt $max_chars ]]; then
        text="${text:0:$max_chars}..."
    fi

    local system_prompt='You are analyzing text to extract ALL decisions, ideas, and commitments. Return a JSON object with arrays for each type.

DECISIONS are choices made between alternatives. Look for:
- English: "decided to", "we'\''ll go with", "let'\''s go with", "the approach is", "chose to", "settled on", "going forward", "from now on"
- Portuguese: "decidi", "decidimos", "vamos usar", "escolhi", "a decisao e", "optei por", "definimos"
- Spanish: "decidi", "decidimos", "vamos a usar", "elegi", "la decision es"

IDEAS are suggestions, explorations, or possibilities. Look for:
- English: "what if", "how about", "we could", "might be worth", "consider", "should explore", "interesting to"
- Portuguese: "e se", "que tal", "podemos", "poderiamos", "seria interessante", "vale a pena"
- Spanish: "que tal si", "podriamos", "seria interesante"

COMMITMENTS are action items, promises, or tasks. Look for:
- English: "I need to", "I have to", "I must", "I will", "I'\''ll", "don'\''t forget", "TODO:", "FIXME:", "make sure to"
- Portuguese: "preciso", "tenho que", "devo", "vou", "nao esquecer", "pendente:"
- Spanish: "necesito", "tengo que", "debo", "voy a", "no olvidar"

RULES:
1. Extract ALL distinct items, not just the first one
2. Combine related sentences into single items
3. Each item should have a clear, concise title (max 100 chars)
4. Skip vague or unclear items
5. Detect the language for each item

Return ONLY valid JSON, no markdown code blocks.'

    local user_prompt="Analyze this text and extract ALL decisions, ideas, and commitments.

Text to analyze:
$text

Return JSON in this exact format:
{
  \"decisions\": [
    {\"title\": \"Brief decision title\", \"category\": \"architecture|technology|process|design|general\", \"rationale\": \"why decided\"}
  ],
  \"ideas\": [
    {\"title\": \"Brief idea title\", \"type\": \"feature|improvement|exploration|refactor\", \"potential\": \"brief value note\"}
  ],
  \"commitments\": [
    {\"title\": \"Brief action item\", \"priority\": \"high|medium|low\", \"due_type\": \"immediate|soon|later|unspecified\"}
  ],
  \"language\": \"en|pt-BR|es\"
}"

    local method content=""
    method=$(extractor_get_method)

    if [[ "$method" == "cli" ]]; then
        debug_log "Using Claude CLI for multi-item extraction"
        local full_prompt="$system_prompt

$user_prompt"
        local cli_response
        cli_response=$(echo "$full_prompt" | timeout "$AI_TIMEOUT" claude \
            --print \
            --model "$AI_MODEL" \
            --output-format json \
            --max-budget-usd "$AI_MAX_BUDGET" \
            --no-session-persistence \
            2>/dev/null) || true

        if [[ -n "$cli_response" ]]; then
            local subtype
            subtype=$(echo "$cli_response" | jq -r '.subtype // empty' 2>/dev/null)
            if [[ "$subtype" == "error_max_budget_usd" ]]; then
                debug_log "AI extraction exceeded budget"
                echo '{"error": "budget_exceeded", "decisions": [], "ideas": [], "commitments": []}'
                return 1
            fi
            content=$(echo "$cli_response" | jq -r '.result // empty' 2>/dev/null)
            if [[ -n "$content" ]]; then
                content=$(echo "$content" | sed 's/^```json//; s/^```//; s/```$//' | tr '\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            fi
        fi

    elif [[ "$method" == "api" ]]; then
        debug_log "Using Anthropic API for multi-item extraction"
        local response
        response=$(curl -s --max-time "$AI_TIMEOUT" \
            -H "Content-Type: application/json" \
            -H "x-api-key: ${ANTHROPIC_API_KEY}" \
            -H "anthropic-version: 2023-06-01" \
            -d "$(jq -n \
                --arg model "claude-3-5-haiku-latest" \
                --arg system "$system_prompt" \
                --arg user "$user_prompt" \
                --argjson max_tokens "$AI_MAX_TOKENS" \
                '{model: $model, max_tokens: $max_tokens, system: $system, messages: [{role: "user", content: $user}]}')" \
            "https://api.anthropic.com/v1/messages" 2>/dev/null)

        if [[ -n "$response" ]]; then
            content=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
            if [[ -z "$content" ]]; then
                local error
                error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
                if [[ -n "$error" ]]; then
                    debug_log "AI API error: $error"
                    echo "{\"error\": \"$error\", \"decisions\": [], \"ideas\": [], \"commitments\": []}"
                    return 1
                fi
            fi
        fi
    else
        echo '{"error": "no_ai_method", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi

    if [[ -z "$content" ]]; then
        echo '{"error": "no_response", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi

    # Validate JSON
    if echo "$content" | jq . >/dev/null 2>&1; then
        content=$(echo "$content" | jq '{
            decisions: (.decisions // []),
            ideas: (.ideas // []),
            commitments: (.commitments // []),
            language: (.language // "en")
        }')
        echo "$content"
        return 0
    else
        local json_match
        json_match=$(echo "$content" | grep -oP '\{[^{}]*"decisions"[^{}]*\}' 2>/dev/null | head -1)
        if [[ -n "$json_match" ]] && echo "$json_match" | jq . >/dev/null 2>&1; then
            echo "$json_match"
            return 0
        fi
        debug_log "AI returned invalid JSON: $content"
        echo '{"error": "invalid_json", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi
}

# ============================================================================
# Pattern-Based Fallback
# ============================================================================

DECISION_PATTERNS_EXTRACT=(
    "decided to " "decision is " "we'll go with " "let's go with "
    "the approach is " "the plan is " "chose to " "settled on " "going forward "
    "decidi " "decidimos " "vamos usar " "escolhi " "a decisao e " "optei por "
    "decidi " "decidimos " "vamos a usar " "elegi " "la decision es "
)

IDEA_PATTERNS_EXTRACT=(
    "what if " "how about " "we could " "might be worth " "consider "
    "should explore " "interesting to " "wouldn't it be "
    "e se " "que tal " "podemos " "poderiamos " "seria interessante "
    "que tal si " "podriamos " "seria interesante "
)

COMMITMENT_PATTERNS_EXTRACT=(
    "I need to " "I have to " "I must " "I will " "I'll "
    "don't forget " "make sure to " "TODO:" "FIXME:"
    "preciso " "tenho que " "devo " "vou " "nao esquecer "
    "necesito " "tengo que " "debo " "voy a " "no olvidar "
)

pattern_extract_all_items() {
    local text="$1"
    local decisions="[]"
    local ideas="[]"
    local commitments="[]"

    for pattern in "${DECISION_PATTERNS_EXTRACT[@]}"; do
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local title
                title=$(echo "$line" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [[ ${#title} -gt 15 ]]; then
                    decisions=$(echo "$decisions" | jq --arg t "$title" '. + [{"title": $t, "category": "general", "rationale": ""}]')
                fi
            fi
        done < <(echo "$text" | grep -i "$pattern" 2>/dev/null || true)
    done

    for pattern in "${IDEA_PATTERNS_EXTRACT[@]}"; do
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local title
                title=$(echo "$line" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [[ ${#title} -gt 15 ]]; then
                    ideas=$(echo "$ideas" | jq --arg t "$title" '. + [{"title": $t, "type": "exploration", "potential": ""}]')
                fi
            fi
        done < <(echo "$text" | grep -i "$pattern" 2>/dev/null || true)
    done

    for pattern in "${COMMITMENT_PATTERNS_EXTRACT[@]}"; do
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local title
                title=$(echo "$line" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [[ ${#title} -gt 15 ]]; then
                    commitments=$(echo "$commitments" | jq --arg t "$title" '. + [{"title": $t, "priority": "medium", "due_type": "unspecified"}]')
                fi
            fi
        done < <(echo "$text" | grep -i "$pattern" 2>/dev/null || true)
    done

    jq -n \
        --argjson d "$decisions" \
        --argjson i "$ideas" \
        --argjson c "$commitments" \
        '{decisions: $d, ideas: $i, commitments: $c, language: "en", method: "pattern"}'
}

# Smart extraction: AI first, pattern fallback
smart_extract_all_items() {
    local text="$1"

    if [[ ${#text} -lt 20 ]]; then
        echo '{"decisions": [], "ideas": [], "commitments": [], "reason": "too_short"}'
        return 0
    fi

    if extractor_ai_enabled; then
        local result
        result=$(ai_extract_all_items "$text")
        local has_error
        has_error=$(echo "$result" | jq -r '.error // empty')
        if [[ -z "$has_error" ]]; then
            echo "$result" | jq '. + {method: "ai"}'
            return 0
        fi
        debug_log "AI extraction failed: $has_error, falling back to patterns"
    fi

    pattern_extract_all_items "$text"
}

# ============================================================================
# Session Summary (uses Haiku for cost efficiency)
# ============================================================================

ai_generate_session_summary() {
    local project="$1"
    local duration="$2"
    local commit_count="$3"
    local highlights="$4"

    if ! extractor_ai_enabled; then
        echo "Session for $project (${duration} minutes, $commit_count commits)"
        return 0
    fi

    local max_chars=6000
    if [[ ${#highlights} -gt $max_chars ]]; then
        highlights="${highlights:0:$max_chars}..."
    fi

    local prompt="Summarize this Claude Code session concisely.

Project: $project | Duration: $duration min | Commits: $commit_count

Highlights:
$highlights

Provide 3-5 bullet points covering: what was done, key decisions, and any follow-ups needed. Max 200 words."

    local result=""
    if extractor_cli_available; then
        local cli_response
        cli_response=$(echo "$prompt" | timeout 30 claude \
            --print --model haiku --output-format json \
            --max-budget-usd 0.10 --no-session-persistence 2>/dev/null) || true
        if [[ -n "$cli_response" ]]; then
            result=$(echo "$cli_response" | jq -r '.result // empty' 2>/dev/null)
        fi
    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        local response
        response=$(curl -s --max-time 30 \
            -H "Content-Type: application/json" \
            -H "x-api-key: ${ANTHROPIC_API_KEY}" \
            -H "anthropic-version: 2023-06-01" \
            -d "$(jq -n --arg model "claude-3-5-haiku-latest" --arg prompt "$prompt" \
                '{model: $model, max_tokens: 500, messages: [{role: "user", content: $prompt}]}')" \
            "https://api.anthropic.com/v1/messages" 2>/dev/null)
        if [[ -n "$response" ]]; then
            result=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
        fi
    fi

    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "Session for $project (${duration} minutes, $commit_count commits)"
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f extractor_ai_enabled extractor_get_method extractor_cli_available
export -f ai_extract_all_items pattern_extract_all_items smart_extract_all_items
export -f ai_generate_session_summary
