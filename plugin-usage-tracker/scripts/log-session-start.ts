#!/usr/bin/env bun
import {
  loadLog,
  saveLog,
  getOrCreateSession,
  generateUUID,
  updateAggregateStats,
  readHookInput,
} from "./utils";

// Helper to get project directory with proper fallback chain
const getProjectDir = (inputCwd?: string) =>
  inputCwd || process.env.CLAUDE_PROJECT_DIR || process.cwd();

async function main() {
  try {
    const input = await readHookInput();
    const projectDir = getProjectDir(input.cwd);

    const log = loadLog();
    const session = getOrCreateSession(
      log,
      input.session_id,
      projectDir,
      input.permission_mode || "default"
    );

    // Add session start event
    session.events.push({
      event_id: generateUUID(),
      event_type: "SessionStart",
      timestamp: new Date().toISOString(),
      tool_name: null,
      tool_use_id: null,
      cwd: projectDir,
      permission_mode: input.permission_mode || "default",
      description: `Session started (source: ${input.source || "unknown"})`,
      input_summary: null,
      output_summary: null,
      duration_ms: null,
      matcher: null,
      is_mcp_tool: false,
      is_plugin_tool: false,
      related_event_id: null,
    });
    
    updateAggregateStats(log);
    saveLog(log);
    
    // Return success (SessionStart can add context)
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: `[Plugin Usage Tracker] Session ${input.session_id} started. Tracking enabled.`
      }
    }));
    
  } catch (error) {
    console.error("Error in session start hook:", error);
    process.exit(1);
  }
}

main();
