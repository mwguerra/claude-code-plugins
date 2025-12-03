/**
 * PreToolUse hook: Validate scripts
 * Exit 0 = allow, Exit 2 = block
 */

interface Input {
  tool_name: string;
  tool_input: { command?: string };
}

const input: Input = await Bun.stdin.json();

if (input.tool_name !== "Bash") {
  process.exit(0);
}

const cmd = input.tool_input.command || "";

// Block sensitive paths
if (/\.env|\.git\/|rm\s+-rf/.test(cmd)) {
  console.error("Blocked: sensitive path");
  process.exit(2);
}

process.exit(0);
