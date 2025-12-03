# PRD Ingestion Examples for MWGuerra Task Manager

These examples show how to convert `.taskmanager/docs/prd.md` into a hierarchical, level-by-level expanded set of tasks inside `.taskmanager/tasks.json`, fully compliant with the MWGuerra Task Manager schema and the Task Manager Skill instructions. (See SKILL.md for mandatory step-by-step expansion logic.)

---

## Example PRD

Content of `.taskmanager/docs/prd.md`:

```markdown
# Bandwidth Widget – Real-time Usage

## Objective
Provide a real-time bandwidth usage widget for project Likker PCAST so users
can monitor current traffic and recent history.

## Requirements
- Show current bandwidth usage (Mbps) updating at least every 5 seconds
- Show a small chart of last 5 minutes of usage
- Include warning state when usage exceeds 80% of configured capacity
- Persist historical data to be used in other reports
- Expose a simple JSON API endpoint for the widget

## Non-goals
- No authentication/authorization changes
- No UI theming changes

## Constraints
- Use existing Laravel + Reverb stack
- Use existing Redis instance for short-term storage
- Frontend is in React with chart.js
```

---

# Expected `tasks.json` Structure (Schema-Compliant)

When ingesting this PRD, `.taskmanager/tasks.json` should be updated with a **level-by-level expansion**:

1. **Level 1 = Epics (top-level tasks)**
2. **Level 2 = Subtasks of each epic**
3. **Level 3 = Subtasks of each Level 2 task (only if complexity requires it)**

Below is an illustrative example.

```jsonc
{
  "version": "1.0.0",
  "project": {
    "id": "likker-pcast",
    "name": "Likker PCAST",
    "description": "Bandwidth monitoring and real-time features."
  },
  "tasks": [
    {
      "id": "1",
      "parentId": null,
      "title": "Implement real-time bandwidth widget for Likker PCAST",
      "description": "Top-level epic covering backend, frontend, realtime streaming, warnings, persistence, and tests.",
      "status": "planned",
      "type": "feature",
      "priority": "high",
      "complexity": {
        "score": 4,
        "scale": "L",
        "reasoning": "Multi-system integration: backend, realtime updates, frontend visualization, persistence.",
        "recommendedSubtasks": 6,
        "expansionPrompt": "Expand into backend, UI, realtime, persistence, thresholds, and testing subtasks."
      },
      "dependencies": [],
      "dependencyAnalysis": {
        "blockedBy": [],
        "blocks": [],
        "conflictsWith": [],
        "notes": ""
      },
      "owner": "",
      "tags": ["frontend", "backend", "realtime", "laravel", "redis", "chartjs"],
      "details": "",
      "testStrategy": "Full coverage with Pest: API endpoints, realtime updates, warning threshold logic.",
      "createdAt": "2025-01-01T00:00:00.000Z",
      "updatedAt": "2025-01-01T00:00:00.000Z",
      "meta": {},
      "subtasks": [

        // ------------------------------------------------------
        // Level 2 Subtasks (expansion of epic)
        // ------------------------------------------------------

        {
          "id": "1.1",
          "parentId": "1",
          "title": "Confirm telemetry source and capacity thresholds",
          "description": "Define where bandwidth metrics originate and what constitutes 80% capacity.",
          "status": "planned",
          "type": "analysis",
          "priority": "high",
          "complexity": {
            "score": 1,
            "scale": "XS",
            "reasoning": "Simple analysis and definitions.",
            "recommendedSubtasks": 0
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["analysis"],
          "details": "",
          "testStrategy": "",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": []
        },

        {
          "id": "1.2",
          "parentId": "1",
          "title": "Implement bandwidth API endpoint",
          "description": "Expose current bandwidth + last 5 minutes history through a Laravel JSON API.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "Requires data access, formatting, and integration with frontend.",
            "recommendedSubtasks": 3,
            "expansionPrompt": "Split into endpoint definition, data retrieval, and response formatting."
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["backend", "laravel", "api"],
          "details": "",
          "testStrategy": "Pest tests verifying endpoint structure and realtime correctness.",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": [
            {
              "id": "1.2.1",
              "parentId": "1.2",
              "title": "Define endpoint contract",
              "description": "Specify response schema, error handling, and required fields.",
              "status": "planned",
              "type": "analysis",
              "priority": "medium",
              "complexity": {
                "score": 1,
                "scale": "XS"
              },
              "dependencies": [],
              "dependencyAnalysis": {},
              "tags": ["backend"],
              "createdAt": "2025-01-01T00:00:00.000Z",
              "updatedAt": "2025-01-01T00:00:00.000Z",
              "subtasks": []
            },
            {
              "id": "1.2.2",
              "parentId": "1.2",
              "title": "Fetch bandwidth data and 5-minute window",
              "description": "Read metrics from telemetry source and compile the rolling window.",
              "status": "planned",
              "type": "feature",
              "priority": "medium",
              "complexity": { "score": 2, "scale": "S" },
              "dependencies": [],
              "dependencyAnalysis": {},
              "tags": ["backend"],
              "createdAt": "2025-01-01T00:00:00.000Z",
              "updatedAt": "2025-01-01T00:00:00.000Z",
              "subtasks": []
            },
            {
              "id": "1.2.3",
              "parentId": "1.2",
              "title": "Build JSON response formatter",
              "description": "Structure consistent payload for frontend consumption.",
              "status": "planned",
              "type": "feature",
              "priority": "medium",
              "complexity": { "score": 1, "scale": "XS" },
              "dependencies": [],
              "dependencyAnalysis": {},
              "tags": ["backend"],
              "createdAt": "2025-01-01T00:00:00.000Z",
              "updatedAt": "2025-01-01T00:00:00.000Z",
              "subtasks": []
            }
          ]
        },

        {
          "id": "1.3",
          "parentId": "1",
          "title": "Implement realtime update mechanism",
          "description": "Use Laravel Reverb to push updates at least every 5 seconds.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "Requires pub/sub, client connections, and fallback handling.",
            "recommendedSubtasks": 2
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["backend", "realtime", "reverb"],
          "details": "",
          "testStrategy": "",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": []
        },

        {
          "id": "1.4",
          "parentId": "1",
          "title": "Create React bandwidth widget UI",
          "description": "Build UI component with chart.js rendering current and 5-minute metrics.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "UI rendering, state management, chart integration.",
            "recommendedSubtasks": 3
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["frontend", "react", "chartjs"],
          "details": "",
          "testStrategy": "",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": []
        },

        {
          "id": "1.5",
          "parentId": "1",
          "title": "Implement warning state at >80% capacity",
          "description": "Show alert style when usage exceeds threshold.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 1, "scale": "XS" },
          "tags": ["frontend"],
          "dependencies": [],
          "dependencyAnalysis": {},
          "subtasks": [],
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z"
        },

        {
          "id": "1.6",
          "parentId": "1",
          "title": "Persist bandwidth history",
          "description": "Store rolling bandwidth metrics in Redis for reports.",
          "status": "planned",
          "priority": "medium",
          "type": "feature",
          "complexity": {
            "score": 2,
            "scale": "S"
          },
          "tags": ["backend", "redis"],
          "dependencies": [],
          "dependencyAnalysis": {},
          "subtasks": [],
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z"
        },

        {
          "id": "1.7",
          "parentId": "1",
          "title": "Add tests and monitoring",
          "description": "Implement Pest tests and minimal monitoring hooks.",
          "status": "planned",
          "type": "chore",
          "priority": "medium",
          "complexity": {
            "score": 2,
            "scale": "S"
          },
          "tags": ["tests", "monitoring"],
          "dependencies": [],
          "dependencyAnalysis": {},
          "subtasks": [],
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z"
        }
      ]
    }
  ]
}
```

---

# Key Conformance Notes

### ✔ Skill Compliance (Level-by-Level)

* Top-level task → many Level 2 tasks → Level 3 subtasks only where needed
* Complexity-driven expansion aligns with the Skill instructions

### ✔ Tasks Schema Compliance

* `status` uses allowed enum values
* `complexity` uses required fields:

  * `score`, `scale`, `reasoning`, `recommendedSubtasks`, `expansionPrompt`
* All required fields from schema included
* All IDs match regex: `^[0-9]+(\.[0-9]+)*$`
* `additionalProperties: false` respected

