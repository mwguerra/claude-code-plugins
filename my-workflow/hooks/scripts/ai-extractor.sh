#!/bin/bash
# My Workflow Plugin - AI Multi-Item Extractor
# Uses Claude to extract ALL decisions, ideas, and commitments from text
# Returns structured JSON with arrays of each type
#
# Authentication priority:
# 1. Claude CLI (uses logged-in account) - preferred
# 2. Direct API with ANTHROPIC_API_KEY - fallback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

# =============================================================================
# Configuration
# =============================================================================

AI_MODEL="${WORKFLOW_AI_MODEL:-haiku}"
AI_MAX_TOKENS=1000
AI_TIMEOUT=20
AI_MAX_BUDGET="0.50"

# =============================================================================
# AI Availability Check
# =============================================================================

# Check if Claude CLI is available
extractor_cli_available() {
    command -v claude >/dev/null 2>&1
}

# Check if AI extraction is enabled and available
extractor_ai_enabled() {
    local enabled
    enabled=$(get_config '.ai.enabled' 'true')
    if [[ "$enabled" != "true" ]]; then
        return 1
    fi

    if extractor_cli_available; then
        return 0
    fi

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        return 0
    fi

    debug_log "AI extraction disabled: no Claude CLI or ANTHROPIC_API_KEY"
    return 1
}

# Get AI method (cli or api)
extractor_get_method() {
    if extractor_cli_available; then
        echo "cli"
    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "api"
    else
        echo "none"
    fi
}

# =============================================================================
# Multi-Item Extraction
# =============================================================================

# Extract ALL decisions, ideas, and commitments from text
# Usage: ai_extract_all_items "text"
# Returns: JSON with arrays of each type
ai_extract_all_items() {
    local text="$1"

    if ! extractor_ai_enabled; then
        echo '{"error": "ai_disabled", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi

    # Truncate very long text
    local max_chars=3000
    if [[ ${#text} -gt $max_chars ]]; then
        text="${text:0:$max_chars}..."
    fi

    local system_prompt='You are analyzing text to extract ALL decisions, ideas, and commitments. Return a JSON object with arrays for each type.

DECISIONS are choices made between alternatives. Look for:
- English: "decided to", "we'\''ll go with", "let'\''s go with", "the approach is", "chose to", "settled on", "the decision is", "going forward", "from now on"
- Portuguese: "decidi", "decidimos", "vamos usar", "escolhi", "a decisão é", "optei por", "definimos"
- Spanish: "decidí", "decidimos", "vamos a usar", "elegí", "la decisión es"

IDEAS are suggestions, explorations, or possibilities. Look for:
- English: "what if", "how about", "we could", "might be worth", "consider", "should explore", "interesting to"
- Portuguese: "e se", "que tal", "podemos", "poderíamos", "seria interessante", "vale a pena"
- Spanish: "qué tal si", "podríamos", "sería interesante"

COMMITMENTS are action items, promises, or tasks. Look for:
- English: "I need to", "I have to", "I must", "I will", "I'\''ll", "don'\''t forget", "TODO:", "FIXME:", "make sure to"
- Portuguese: "preciso", "tenho que", "devo", "vou", "não esquecer", "pendente:"
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

    local method
    method=$(extractor_get_method)

    local content=""

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
            # Check for budget error
            local subtype
            subtype=$(echo "$cli_response" | jq -r '.subtype // empty' 2>/dev/null)
            if [[ "$subtype" == "error_max_budget_usd" ]]; then
                debug_log "AI extraction exceeded budget"
                echo '{"error": "budget_exceeded", "decisions": [], "ideas": [], "commitments": []}'
                return 1
            fi

            # Extract result from CLI response
            content=$(echo "$cli_response" | jq -r '.result // empty' 2>/dev/null)

            if [[ -n "$content" ]]; then
                # Strip markdown code blocks if present
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
                '{
                    model: $model,
                    max_tokens: $max_tokens,
                    system: $system,
                    messages: [{role: "user", content: $user}]
                }')" \
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
        debug_log "No AI method available for extraction"
        echo '{"error": "no_ai_method", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi

    # Validate and return JSON
    if [[ -z "$content" ]]; then
        debug_log "AI extraction failed: no content"
        echo '{"error": "no_response", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi

    # Try to parse as JSON
    if echo "$content" | jq . >/dev/null 2>&1; then
        # Ensure required arrays exist
        content=$(echo "$content" | jq '{
            decisions: (.decisions // []),
            ideas: (.ideas // []),
            commitments: (.commitments // []),
            language: (.language // "en")
        }')
        echo "$content"
        return 0
    else
        # Try to extract JSON from response
        local json_match
        json_match=$(echo "$content" | grep -oP '\{[^{}]*"decisions"[^{}]*\}' | head -1)
        if [[ -n "$json_match" ]] && echo "$json_match" | jq . >/dev/null 2>&1; then
            echo "$json_match"
            return 0
        fi
        debug_log "AI returned invalid JSON: $content"
        echo '{"error": "invalid_json", "decisions": [], "ideas": [], "commitments": []}'
        return 1
    fi
}

# =============================================================================
# Pattern-Based Fallback
# =============================================================================

# Multi-language patterns
DECISION_PATTERNS_EXTRACT=(
    "decided to " "decision is " "we'll go with " "let's go with "
    "the approach is " "the plan is " "chose to " "settled on " "going forward "
    "decidi " "decidimos " "vamos usar " "escolhi " "a decisão é " "optei por "
    "decidí " "decidimos " "vamos a usar " "elegí " "la decisión es "
)

IDEA_PATTERNS_EXTRACT=(
    "what if " "how about " "we could " "might be worth " "consider "
    "should explore " "interesting to " "wouldn't it be "
    "e se " "que tal " "podemos " "poderíamos " "seria interessante "
    "qué tal si " "podríamos " "sería interesante "
)

COMMITMENT_PATTERNS_EXTRACT=(
    "I need to " "I have to " "I must " "I will " "I'll "
    "don't forget " "make sure to " "TODO:" "FIXME:"
    "preciso " "tenho que " "devo " "vou " "não esquecer "
    "necesito " "tengo que " "debo " "voy a " "no olvidar "
)

# Extract items using pattern matching (fallback)
# Usage: pattern_extract_all_items "text"
pattern_extract_all_items() {
    local text="$1"
    local decisions="[]"
    local ideas="[]"
    local commitments="[]"

    # Extract decisions
    for pattern in "${DECISION_PATTERNS_EXTRACT[@]}"; do
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local title=$(echo "$line" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [[ ${#title} -gt 15 ]]; then
                    local escaped_title=$(echo "$title" | jq -Rs '.')
                    if [[ "$decisions" == "[]" ]]; then
                        decisions="[{\"title\": $escaped_title, \"category\": \"general\", \"rationale\": \"\"}]"
                    else
                        decisions=$(echo "$decisions" | jq --arg t "$title" '. + [{"title": $t, "category": "general", "rationale": ""}]')
                    fi
                fi
            fi
        done < <(echo "$text" | grep -i "$pattern" 2>/dev/null || true)
    done

    # Extract ideas
    for pattern in "${IDEA_PATTERNS_EXTRACT[@]}"; do
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local title=$(echo "$line" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [[ ${#title} -gt 15 ]]; then
                    local escaped_title=$(echo "$title" | jq -Rs '.')
                    if [[ "$ideas" == "[]" ]]; then
                        ideas="[{\"title\": $escaped_title, \"type\": \"exploration\", \"potential\": \"\"}]"
                    else
                        ideas=$(echo "$ideas" | jq --arg t "$title" '. + [{"title": $t, "type": "exploration", "potential": ""}]')
                    fi
                fi
            fi
        done < <(echo "$text" | grep -i "$pattern" 2>/dev/null || true)
    done

    # Extract commitments
    for pattern in "${COMMITMENT_PATTERNS_EXTRACT[@]}"; do
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local title=$(echo "$line" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [[ ${#title} -gt 15 ]]; then
                    local escaped_title=$(echo "$title" | jq -Rs '.')
                    if [[ "$commitments" == "[]" ]]; then
                        commitments="[{\"title\": $escaped_title, \"priority\": \"medium\", \"due_type\": \"unspecified\"}]"
                    else
                        commitments=$(echo "$commitments" | jq --arg t "$title" '. + [{"title": $t, "priority": "medium", "due_type": "unspecified"}]')
                    fi
                fi
            fi
        done < <(echo "$text" | grep -i "$pattern" 2>/dev/null || true)
    done

    # Return combined JSON
    jq -n \
        --argjson d "$decisions" \
        --argjson i "$ideas" \
        --argjson c "$commitments" \
        '{decisions: $d, ideas: $i, commitments: $c, language: "en", method: "pattern"}'
}

# =============================================================================
# Smart Extraction (AI with Pattern Fallback)
# =============================================================================

# Extract all items using AI, fall back to patterns if AI fails
# Usage: smart_extract_all_items "text"
smart_extract_all_items() {
    local text="$1"

    # Skip very short content
    if [[ ${#text} -lt 20 ]]; then
        echo '{"decisions": [], "ideas": [], "commitments": [], "reason": "too_short"}'
        return 0
    fi

    # Try AI extraction first
    if extractor_ai_enabled; then
        local result
        result=$(ai_extract_all_items "$text")

        # Check if we got valid results
        local has_error=$(echo "$result" | jq -r '.error // empty')
        if [[ -z "$has_error" ]]; then
            debug_log "AI extraction successful"
            echo "$result" | jq '. + {method: "ai"}'
            return 0
        fi

        debug_log "AI extraction failed: $has_error, falling back to patterns"
    fi

    # Fall back to pattern matching
    debug_log "Using pattern-based extraction"
    pattern_extract_all_items "$text"
}

# =============================================================================
# Smart Filename Generation
# =============================================================================

# Generate a descriptive, short filename using AI
# Usage: ai_generate_filename "title or description" "type" [max_length]
ai_generate_filename() {
    local title="$1"
    local item_type="${2:-note}"
    local max_length="${3:-40}"

    # Fast path: if AI not available, use simple slugify
    if ! extractor_ai_enabled; then
        echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-$max_length
        return 0
    fi

    local prompt="Generate a short, descriptive filename (max $max_length chars, lowercase, hyphens only) for this $item_type:

\"$title\"

Rules:
- Use lowercase letters and hyphens only
- No special characters or spaces
- Be concise but descriptive (capture the essence)
- Max $max_length characters
- No file extension

Return ONLY the filename, nothing else."

    local filename
    if extractor_cli_available; then
        local response
        response=$(echo "$prompt" | timeout 30 claude --print --model haiku --output-format json --max-budget-usd 0.10 --no-session-persistence 2>/dev/null || echo "")
        if [[ -n "$response" ]]; then
            filename=$(echo "$response" | jq -r '.result // empty' 2>/dev/null | tr -d '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        fi
    fi

    # Clean and validate the result
    if [[ -n "$filename" && ${#filename} -le $max_length ]]; then
        # Ensure only valid characters
        filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
        if [[ -n "$filename" ]]; then
            echo "$filename"
            return 0
        fi
    fi

    # Fallback to simple slugify
    echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-$max_length
}

# Smart filename with optional AI enhancement
# Usage: smart_filename "title" "type" [max_length]
smart_filename() {
    local title="$1"
    local item_type="${2:-note}"
    local max_length="${3:-40}"

    # Check if AI filenames are enabled
    local use_ai=$(get_config '.vault.smartFilenames' 'true')
    if [[ "$use_ai" == "true" ]]; then
        ai_generate_filename "$title" "$item_type" "$max_length"
    else
        # Simple slugify
        echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-$max_length
    fi
}

# =============================================================================
# GitHub URL Helpers
# =============================================================================

# Get GitHub repository URL for current directory
get_github_repo_url() {
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ -z "$remote_url" ]]; then
        return 1
    fi

    # Convert SSH URL to HTTPS
    if [[ "$remote_url" == git@github.com:* ]]; then
        remote_url="https://github.com/${remote_url#git@github.com:}"
    fi

    # Remove .git suffix
    remote_url="${remote_url%.git}"

    echo "$remote_url"
}

# Generate GitHub commit URL
# Usage: get_commit_github_url "commit_hash"
get_commit_github_url() {
    local commit_hash="$1"
    local repo_url
    repo_url=$(get_github_repo_url)

    if [[ -n "$repo_url" ]]; then
        echo "${repo_url}/commit/${commit_hash}"
    else
        echo ""
    fi
}

# Generate markdown link to GitHub commit
# Usage: get_commit_link "commit_hash" [message]
get_commit_link() {
    local commit_hash="$1"
    local message="${2:-$commit_hash}"
    local short_hash="${commit_hash:0:7}"
    local github_url
    github_url=$(get_commit_github_url "$commit_hash")

    if [[ -n "$github_url" ]]; then
        echo "[\`${short_hash}\`](${github_url})"
    else
        echo "\`${short_hash}\`"
    fi
}

# =============================================================================
# Export Functions
# =============================================================================

export -f extractor_ai_enabled extractor_get_method
export -f ai_extract_all_items pattern_extract_all_items smart_extract_all_items
export -f ai_generate_filename smart_filename
export -f get_github_repo_url get_commit_github_url get_commit_link
