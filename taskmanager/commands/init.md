---
allowed-tools: [Read, Write, Glob]
description: Initialize a .taskmanager directory in the project if it does not exist.
---

# Init Task Manager Command

You are implementing `/mwguerra:taskmanager:init`.

## Behavior

1. Check if `.taskmanager` exists:
   - Use `Glob` or `Read` on `.taskmanager/tasks.json`.
2. If `.taskmanager` already exists:
   - Inform the user and do nothing unless they explicitly ask for a reset.
3. If it does not exist:
   - Copy the template structure from:
     - `~/.claude/skills/mwguerra/taskmanager/template/.taskmanager/**`
   - For each file in the template tree:
     - Use `Read` to load the template.
     - Use `Write` to create the corresponding file under `.taskmanager`.
4. Summarize:
   - Which files/directories were created.
   - How to run `/mwguerra:taskmanager:plan` next.
