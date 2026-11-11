# Codex Delivery Workflow

## 1. Mandatory Rules

These instructions apply to **every code change** in this repository, including bug fixes, refactoring, features, tests, configuration changes, and CI updates.

**Core principle: No unverified code may be committed or pushed.**

Codex MUST:

- Inspect relevant existing code, tests, and repository conventions before making changes.
- Make the smallest reasonable change that satisfies the request.
- Write or update focused tests alongside production changes.
- Run all required quality gates in the specified order.
- Verify Git changes before creating a commit.
- Never bypass failed checks or report unexecuted checks as passing.
- Preserve unrelated user changes.

If any mandatory step cannot be completed, report the blocker clearly instead of silently skipping it.

## 2. Before Writing Code

Before modifying files:

1. Read the relevant implementation and existing tests.
2. Identify affected APIs, state transitions, validation rules, and error-handling paths.
3. Inspect existing architecture, naming conventions, and testing patterns.
4. Check `git status --short` to identify pre-existing changes.
5. Determine the smallest implementation and test scope.

Do not overwrite, revert, or include unrelated user changes.

Avoid unrelated refactoring, unnecessary dependencies, and speculative improvements.

## 3. Implementation and Testing

Every behavior-changing implementation MUST include appropriate test coverage.

Where relevant, tests MUST cover:

- New or changed API contracts.
- Expected behavior and successful execution.
- State transitions and edge cases.
- Input validation and invalid inputs.
- Error handling and failure recovery.
- Regression scenarios for fixed bugs.

Testing requirements:

- Prefer focused unit and widget tests.
- Follow existing test organization and conventions.
- Keep tests deterministic and independent.
- Do not delete, disable, or weaken existing tests merely to make checks pass.
- Do not replace meaningful assertions with superficial checks.
- Update existing tests when intentionally changing behavior.

For changes that do not require new tests, explain why in the final report.

## 4. Required Quality Gates

After implementation, Codex MUST execute the following commands from the repository root, **sequentially and in this exact order**:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage
flutter build web --release
```

### Execution requirements

1. Run each command and inspect its exit code.
2. A command passes only when its exit code is `0`.
3. Do not start the next gate if the current gate fails.
4. Fix code-related failures and restart verification from the first gate.
5. If formatting fails, format the affected files, then restart verification.
6. Never substitute a partial test run for the required full test suite.
7. Never claim a gate passed if it was skipped, interrupted, or not executed.

All four gates MUST pass for the final implementation before a commit or push is allowed.

### Environment failures

If verification is blocked by the environment, including missing SDKs, unavailable dependencies, permissions, or infrastructure issues:

- Report the failing command and relevant error output.
- Distinguish environment failures from code failures.
- Mark verification as blocked, not passed.
- Do not commit or push.
- Wait for user direction when the environment issue cannot be resolved safely.

## 5. Git Verification

After all four quality gates pass, run:

```powershell
git diff --check
git status --short
git diff --stat
git diff
```

Codex MUST:

- Ensure `git diff --check` passes.
- Review the final diff for unintended modifications.
- Verify that only task-related files are included.
- Preserve pre-existing user changes.
- Check for accidental secrets, debug statements, and generated artifacts.
- Avoid staging unrelated files.

If changes are made after successful verification, rerun all four quality gates before committing.

## 6. Commit Policy

Commits MUST be single-purpose and follow:

```text
<action>: <short imperative message>
```

Examples:

```text
fix: handle expired authentication tokens
feat: add order status validation
refactor: simplify checkout state handling
test: cover payment failure scenarios
docs: clarify deployment instructions
```

Before committing:

1. Confirm all four quality gates passed.
2. Confirm `git diff --check` passed.
3. Confirm the staged changes belong to the current task.
4. Stage only intended files using explicit paths.
5. Inspect `git diff --cached --check` and `git diff --cached`.
6. Commit using the required naming convention.

Do not use `git add .` or `git add -A` when unrelated changes exist.

**Passing verification permits a commit; it does not authorize one.**

Create a commit only when explicitly requested by the user or required by an already authorized task.

## 7. Push and CI Policy

Never push to `origin` unless:

- All four local quality gates passed.
- Git verification passed.
- The commit contains only intended changes.
- The user explicitly authorized the push.

Do not use `--no-verify`, force-push, or bypass repository protections to work around failures.

GitHub Actions mirrors the required gates in:

```text
.github/workflows/flutter-ci.yml
```

Staging distribution runs only after CI succeeds for `main`.

Local verification does not replace CI verification.

Do not claim that CI or staging succeeded unless the corresponding results have actually been verified.

## 8. Failure Handling

When any step fails:

1. Stop the delivery process.
2. Identify the failing command or operation.
3. Determine whether the failure is caused by code or the environment.
4. Fix code-related issues within the task scope.
5. Restart quality gates from the beginning after changes.
6. Report unresolved blockers accurately.

Never:

- Ignore failing tests.
- Disable analysis rules to hide errors.
- Remove assertions to obtain a passing result.
- Commit with incomplete verification.
- Push unverified changes.
- Treat environment failures as successful checks.
- Claim success without evidence.

## 9. Final Delivery Report

At the end of every code task, provide a concise report.

### Changes

Summarize the implementation and affected files.

### Tests

Describe added or updated tests and any relevant coverage limitations.

### Verification

| Quality gate | Status |
|---|---|
| Dart format | PASS / FAIL / BLOCKED / NOT RUN |
| Flutter analyze | PASS / FAIL / BLOCKED / NOT RUN |
| Flutter tests | PASS / FAIL / BLOCKED / NOT RUN |
| Flutter web release build | PASS / FAIL / BLOCKED / NOT RUN |
| Git diff check | PASS / FAIL / NOT RUN |

Report actual execution results only.

### Git

Report whether changes were committed or pushed, and provide the commit hash if applicable.

### Blockers

Describe any unresolved failures, environmental limitations, or actions requiring user direction.

## 10. Definition of Done

A code task is ready for delivery only when:

- [ ] Requested behavior is implemented.
- [ ] Relevant tests are added or updated.
- [ ] Existing behavior is preserved unless intentionally changed.
- [ ] Dart formatting passes.
- [ ] Flutter static analysis passes.
- [ ] Flutter tests pass.
- [ ] Flutter web release build passes.
- [ ] Git diff verification passes.
- [ ] Unrelated user changes remain untouched.
- [ ] Final results are reported accurately.

If any mandatory item is incomplete, mark the task as **BLOCKED** or **INCOMPLETE**, not DONE.

**Final rule: Never trade verification correctness for delivery speed.**