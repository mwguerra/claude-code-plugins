## Global Guidelines
- Always plan before implementation. If any requirement is unclear, ask clarifying questions. Use the `AskUserQuestionTool` when appropriate.
- Never add Claude as a co-author in commits. This is a strict rule.
- If you need to execute any sudo command, ask me to do it.

## Development Guidelines
- After implementing any feature or fix, ensure appropriate tests are in place:
  - Tests must cover the new functionality or the relevant edge cases.
  - Tests must actually validate the intended behavior (avoid false positives).
  - All tests must pass (green) before committing.
- Once tests are verified and passing, commit the changes using **conventional commit messages** and push to `origin`.
- For Laravel and Filament projects, always prefer creating files via Artisan commands instead of manual file creation.
- When writing tests, run them in parallel whenever it makes sense and does not introduce flakiness or incorrect results.
