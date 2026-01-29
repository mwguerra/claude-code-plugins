#!/bin/bash
# My Workflow Plugin - AI Content Analyzer
# Uses Claude Haiku for intelligent content analysis when patterns don't match
# Supports multiple languages (English, Portuguese BR, Spanish, etc.)
#
# Authentication priority:
# 1. Claude CLI (uses logged-in account) - preferred
# 2. Direct API with ANTHROPIC_API_KEY - fallback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

# ============================================================================
# Configuration
# ============================================================================

# Model to use for analysis (haiku is cheapest/fastest)
AI_MODEL="${WORKFLOW_AI_MODEL:-haiku}"
AI_MAX_TOKENS=500
AI_TIMEOUT=15
AI_MAX_BUDGET="0.01"  # Max $0.01 per analysis

# Check if Claude CLI is available and logged in
claude_cli_available() {
    command -v claude >/dev/null 2>&1
}

# Check if AI analysis is enabled
ai_enabled() {
    # Check config first
    local enabled
    enabled=$(get_config '.ai.enabled' 'true')
    if [[ "$enabled" != "true" ]]; then
        return 1
    fi

    # Check for Claude CLI first (uses logged-in account)
    if claude_cli_available; then
        return 0
    fi

    # Fall back to API key
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        return 0
    fi

    debug_log "AI analysis disabled: no Claude CLI or ANTHROPIC_API_KEY"
    return 1
}

# Get the AI method to use
get_ai_method() {
    if claude_cli_available; then
        echo "cli"
    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "api"
    else
        echo "none"
    fi
}

# ============================================================================
# AI Analysis Function
# ============================================================================

# Analyze text content and return structured JSON
# Usage: analyze_content "text" "analysis_type"
# analysis_type: decision|idea|commitment|summary|auto
analyze_content() {
    local text="$1"
    local analysis_type="${2:-auto}"

    if ! ai_enabled; then
        echo "{\"error\": \"ai_disabled\"}"
        return 1
    fi

    # Truncate very long text to save tokens
    local max_chars=2000
    if [[ ${#text} -gt $max_chars ]]; then
        text="${text:0:$max_chars}..."
    fi

    # Build the analysis prompt based on type
    local system_prompt
    local user_prompt

    case "$analysis_type" in
        decision)
            system_prompt="You are analyzing text to extract decisions. A decision is a choice made between alternatives, often with rationale. Output JSON only."
            user_prompt="Analyze this text for decisions. Extract:
- found: boolean (true if a decision exists)
- title: short decision title (max 100 chars)
- category: one of [architecture, technology, process, design, general]
- rationale: why this decision was made (if mentioned)
- language: detected language code (en, pt-BR, es, etc.)

Text to analyze:
$text

Respond with valid JSON only, no markdown."
            ;;
        idea)
            system_prompt="You are analyzing text to extract ideas and suggestions. An idea is a potential improvement, feature, or approach worth exploring. Output JSON only."
            user_prompt="Analyze this text for ideas. Extract:
- found: boolean (true if an idea/suggestion exists)
- title: short idea title (max 100 chars)
- type: one of [feature, improvement, exploration, question, refactor]
- potential: brief note on potential value
- language: detected language code (en, pt-BR, es, etc.)

Text to analyze:
$text

Respond with valid JSON only, no markdown."
            ;;
        commitment)
            system_prompt="You are analyzing text to extract commitments and action items. A commitment is something someone promises to do or a task that needs doing. Output JSON only."
            user_prompt="Analyze this text for commitments/action items. Extract:
- found: boolean (true if a commitment/todo exists)
- title: short action item title (max 100 chars)
- priority: one of [high, normal, low]
- due_type: one of [immediate, soon, later, unspecified]
- language: detected language code (en, pt-BR, es, etc.)

Text to analyze:
$text

Respond with valid JSON only, no markdown."
            ;;
        summary)
            system_prompt="You are summarizing technical work content. Be concise and focus on what was accomplished. Output JSON only."
            user_prompt="Summarize this work content. Extract:
- summary: 1-2 sentence summary of what was done
- files: list of files mentioned (if any)
- category: one of [implementation, bugfix, refactor, documentation, testing, other]
- language: detected language code (en, pt-BR, es, etc.)

Text to analyze:
$text

Respond with valid JSON only, no markdown."
            ;;
        auto|*)
            system_prompt="You are analyzing text to classify and extract structured information. The text may contain decisions, ideas, commitments, or general content. Detect the language and extract relevant information. Output JSON only."
            user_prompt="Analyze this text and classify it. Extract:
- type: one of [decision, idea, commitment, general, none]
- found: boolean (true if meaningful content to track)
- title: short descriptive title (max 100 chars)
- category: relevant category based on content type
- language: detected language code (en, pt-BR, es, etc.)
- summary: brief summary if content is substantial

Common patterns in multiple languages:
- Decisions: 'decided to', 'decidi', 'vamos usar', 'escolhi'
- Ideas: 'what if', 'e se', 'podemos', 'que tal'
- Commitments: 'I need to', 'preciso', 'tenho que', 'vou fazer'

Text to analyze:
$text

Respond with valid JSON only, no markdown."
            ;;
    esac

    # Determine which method to use
    local ai_method
    ai_method=$(get_ai_method)

    local content=""

    if [[ "$ai_method" == "cli" ]]; then
        # Use Claude CLI (logged-in account)
        debug_log "Using Claude CLI for analysis"

        local full_prompt="$system_prompt

$user_prompt"

        # Run claude CLI with print mode, haiku model, JSON output
        local cli_response
        cli_response=$(echo "$full_prompt" | timeout "$AI_TIMEOUT" claude \
            --print \
            --model "$AI_MODEL" \
            --output-format json \
            --max-budget-usd "$AI_MAX_BUDGET" \
            --no-session-persistence \
            2>/dev/null) || true

        if [[ -n "$cli_response" ]]; then
            # CLI returns JSON with result field
            content=$(echo "$cli_response" | jq -r '.result // empty' 2>/dev/null)
            if [[ -z "$content" ]]; then
                # Try direct content
                content="$cli_response"
            fi
        fi

    elif [[ "$ai_method" == "api" ]]; then
        # Use direct API call
        debug_log "Using Anthropic API for analysis"

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
                    echo "{\"error\": \"$error\"}"
                    return 1
                fi
            fi
        fi
    else
        debug_log "No AI method available"
        echo "{\"error\": \"no_ai_method\"}"
        return 1
    fi

    # Check if we got content
    if [[ -z "$content" ]]; then
        debug_log "AI analysis failed: no content"
        echo "{\"error\": \"no_response\"}"
        return 1
    fi

    # Validate JSON response
    if echo "$content" | jq . >/dev/null 2>&1; then
        echo "$content"
        return 0
    else
        # Try to extract JSON from response (model sometimes adds text)
        local json_match
        json_match=$(echo "$content" | grep -oP '\{[^}]+\}' | head -1)
        if [[ -n "$json_match" ]] && echo "$json_match" | jq . >/dev/null 2>&1; then
            echo "$json_match"
            return 0
        fi
        debug_log "AI returned invalid JSON: $content"
        echo "{\"error\": \"invalid_json\", \"raw\": $(echo "$content" | jq -Rs .)}"
        return 1
    fi
}

# ============================================================================
# Multi-language Pattern Matching
# ============================================================================

# Extended patterns for multiple languages
DECISION_PATTERNS_MULTI=(
    # English
    "decided to " "decision is " "we'll go with " "let's go with "
    "the approach is " "the plan is " "chose to " "picked " "settled on "
    # Portuguese BR
    "decidi " "decidimos " "vamos usar " "vou usar " "escolhi "
    "a decisão é " "optei por " "resolvi " "definimos "
    # Spanish
    "decidí " "decidimos " "vamos a usar " "elegí " "la decisión es "
)

IDEA_PATTERNS_MULTI=(
    # English
    "what if " "how about " "we could " "might be worth " "consider "
    "wouldn't it be " "interesting to " "should explore "
    # Portuguese BR
    "e se " "que tal " "podemos " "poderíamos " "seria interessante "
    "vale a pena " "deveríamos explorar " "uma ideia: "
    # Spanish
    "qué tal si " "podríamos " "sería interesante " "considera "
)

COMMITMENT_PATTERNS_MULTI=(
    # English
    "I need to " "I have to " "I must " "I will " "I'll "
    "don't forget " "make sure to " "TODO:" "FIXME:"
    # Portuguese BR
    "preciso " "tenho que " "devo " "vou " "não esquecer "
    "lembrar de " "fazer: " "pendente: "
    # Spanish
    "necesito " "tengo que " "debo " "voy a " "no olvidar "
)

# Check for pattern match in multiple languages
# Usage: check_patterns_multi "text" "pattern_type"
# Returns: 0 if found, 1 if not found
check_patterns_multi() {
    local text="$1"
    local pattern_type="$2"

    local -n patterns
    case "$pattern_type" in
        decision) patterns=DECISION_PATTERNS_MULTI ;;
        idea) patterns=IDEA_PATTERNS_MULTI ;;
        commitment) patterns=COMMITMENT_PATTERNS_MULTI ;;
        *) return 1 ;;
    esac

    for pattern in "${patterns[@]}"; do
        if echo "$text" | grep -qi "$pattern"; then
            return 0
        fi
    done

    return 1
}

# ============================================================================
# High-level Analysis Function
# ============================================================================

# Analyze content with pattern pre-filter + AI fallback
# Usage: smart_analyze "text" "type"
# Returns JSON with analysis results
smart_analyze() {
    local text="$1"
    local content_type="${2:-auto}"

    # Skip very short content
    if [[ ${#text} -lt 10 ]]; then
        echo "{\"found\": false, \"reason\": \"too_short\"}"
        return 0
    fi

    # Try pattern matching first (fast path)
    if [[ "$content_type" == "auto" ]]; then
        if check_patterns_multi "$text" "decision"; then
            content_type="decision"
        elif check_patterns_multi "$text" "idea"; then
            content_type="idea"
        elif check_patterns_multi "$text" "commitment"; then
            content_type="commitment"
        fi
    fi

    # If patterns matched, still use AI for better extraction
    # If no patterns matched, use AI to check for content anyway
    if ai_enabled; then
        local ai_result
        ai_result=$(analyze_content "$text" "$content_type")

        # Add pattern match info
        local pattern_matched="false"
        if check_patterns_multi "$text" "decision" || \
           check_patterns_multi "$text" "idea" || \
           check_patterns_multi "$text" "commitment"; then
            pattern_matched="true"
        fi

        echo "$ai_result" | jq --arg pm "$pattern_matched" '. + {pattern_matched: ($pm == "true")}'
        return 0
    else
        # AI not available, use pattern matching only
        if check_patterns_multi "$text" "$content_type" 2>/dev/null; then
            # Extract basic info from pattern match
            local title
            title=$(echo "$text" | head -1 | cut -c1-100)
            echo "{\"found\": true, \"type\": \"$content_type\", \"title\": $(echo "$title" | jq -Rs .), \"pattern_matched\": true, \"ai_analyzed\": false}"
            return 0
        else
            echo "{\"found\": false, \"pattern_matched\": false, \"ai_analyzed\": false}"
            return 0
        fi
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f ai_enabled analyze_content check_patterns_multi smart_analyze
