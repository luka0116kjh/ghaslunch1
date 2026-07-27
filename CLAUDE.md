Skill Auto-Routing and Agent Execution Rules

When the user requests a task, first inspect the currently available skills and automatically select the most relevant skill or skill sequence.

The agent must never assume that a skill exists merely because it is mentioned in this document. Before using a skill, confirm that it is installed, available in the current environment, and has a readable SKILL.md.

⸻

1. Core Principles

1. Analyze the user’s request automatically, even when the user does not specify a skill.
2. Select the most specific available skill that directly matches the task.
3. Prefer one specialized skill when it can complete the task independently.
4. For multi-step tasks, combine only the necessary skills in a logical execution order.
5. Avoid invoking unrelated, redundant, or overly broad skills.
6. Read and follow the selected skill’s SKILL.md before executing it.
7. Never claim that a skill was used when it was unavailable or could not be loaded.
8. Use a general reasoning or tool-based approach only when no suitable skill is available.
9. Focus user-facing responses on the completed work rather than providing a long explanation of the routing process.
10. Preserve the user’s existing code, architecture, formatting, and project conventions unless changes are necessary.
11. Do not perform destructive, external, or irreversible actions unless the user explicitly requested them.
12. Verify the result before reporting the task as complete.

⸻

2. Skill Discovery and Availability

Before selecting a skill:

1. Inspect the currently installed or exposed skill registry.
2. Confirm that the candidate skill exists.
3. Confirm that its SKILL.md can be accessed.
4. Confirm that the tools required by the skill are available.
5. Confirm that the skill is compatible with the current task and environment.
6. If the skill is unavailable, do not simulate or pretend to execute it.
7. Select the closest available alternative or fall back to a general approach.

A skill may have the following states:

* DISCOVERED: The skill name is known.
* AVAILABLE: The skill exists in the current environment.
* LOADED: Its SKILL.md has been read successfully.
* SELECTED: The skill has been chosen for the task.
* EXECUTED: The skill workflow has been performed.
* VERIFIED: The result has passed appropriate checks.
* FAILED: The skill could not complete the task.
* SKIPPED: The skill was unnecessary or unavailable.

Only skills in the AVAILABLE and LOADED states may be executed.

⸻

3. Skill Selection Priority

When multiple skills could apply, use the following priority order:

1. A skill explicitly requested by the user
2. A task-specific implementation skill
3. A framework- or language-specific skill
4. A testing or verification skill
5. A review or security-analysis skill
6. A commit, pull request, deployment, or publishing skill
7. A general-purpose skill
8. General reasoning without a skill

Do not prioritize a general skill over a more specific available skill.

Example:

For a React performance bug:

1. react-performance
2. react-testing
3. verification-loop
4. caveman-review

Do not begin with a generic code-review skill when a specialized React performance skill is available.

⸻

4. Task Classification

Before execution, classify the request using the following dimensions:

Task Type

* Planning
* Investigation
* Implementation
* Bug fixing
* Testing
* Verification
* Code review
* Security review
* Documentation
* Design
* Refactoring
* Commit
* Pull request
* Deployment
* Communication
* Data analysis

Target

* Repository
* File
* Component
* API
* Database
* UI screen
* Figma design
* Document
* Spreadsheet
* Calendar
* Email
* Notion workspace
* External service

Risk Level

* LOW: Read-only analysis, planning, explanation, local inspection
* MEDIUM: Local code or document modification
* HIGH: External communication, Git push, pull request creation, deployment, deletion, production configuration changes, database mutations

Expected Output

* Analysis
* Code
* Patch
* Test result
* Review report
* Commit
* Pull request
* Document
* Design
* Deployment
* Message

The selected skill must match the task type, target, risk level, and expected output.

⸻

5. Automatic Skill Selection

Code Development

Use the most specific language-, framework-, or platform-specific implementation skill.

Examples:

* React → react-patterns
* React Native → react-native-patterns
* Java → java-coding-standards
* Spring Boot → Spring Boot implementation skills
* Kotlin → Kotlin implementation skills
* Android → Android or Kotlin skills
* Swift → Swift implementation skills
* SwiftUI → SwiftUI skills
* Python → Python implementation skills
* Database → SQL or database-specific skills

⸻

Bug Fixes and Failed Tests

Use:

* Testing skills
* Verification skills
* Debugging skills
* Defect-fixing skills
* Framework-specific troubleshooting skills

Preferred workflow:

1. Reproduce the issue
2. Identify the failure boundary
3. Form a testable hypothesis
4. Apply the smallest safe fix
5. Run targeted verification
6. Run broader regression checks
7. Review the final diff

Do not modify unrelated code while fixing a defect.

⸻

Code Review

Use:

* caveman-review
* security-review
* Framework-specific review skills
* Performance review skills

Choose based on the review objective:

* General code quality → caveman-review
* Security risk → security-review
* React performance → react-performance
* Architecture → architecture or repository-analysis skills

⸻

Git Commits and Pull Requests

Use:

* caveman-commit
* GitHub skills
* yeet
* Pull request creation skills

Before committing:

1. Inspect the working tree.
2. Review the diff.
3. Confirm that unrelated files are excluded.
4. Run relevant tests.
5. Generate a clear commit message.
6. Commit only the intended changes.

Before creating a pull request:

1. Confirm the branch and target branch.
2. Summarize the change accurately.
3. Include verification results.
4. Mention known limitations.
5. Avoid claiming tests passed when they were not run.

Git push and pull request creation require an explicit user request.

⸻

Security Analysis

Use:

* security-scan
* security-review
* security-bounty-hunter
* Language-specific security skills
* Framework-specific security skills

Security analysis must:

1. Identify the threat model.
2. Separate confirmed findings from hypotheses.
3. Provide evidence for each finding.
4. Assess exploitability and impact.
5. Recommend remediation.
6. Avoid destructive testing unless explicitly authorized.
7. Stay within the user’s authorized environment.

⸻

React Development

Use:

* react-patterns
* react-testing
* react-performance

Prefer:

* Reusable components
* Custom hooks
* Clear state boundaries
* Separation of business logic and presentation
* Type-safe props
* Minimal unnecessary rendering
* Accessible interactions
* Predictable data flow

⸻

Java and Spring

Use:

* java-coding-standards
* Spring Boot implementation skills
* Spring testing skills
* Java review skills

Always preserve:

* Package structure
* Dependency injection patterns
* Exception-handling conventions
* DTO and entity boundaries
* Transaction boundaries
* Existing build-tool conventions

⸻

Kotlin and Android

Use Kotlin- or Android-specific skills.

Always verify:

* Lifecycle safety
* State handling
* Coroutine scope usage
* Null safety
* Navigation behavior
* Configuration changes
* Android version compatibility
* Build configuration

⸻

Swift and iOS

Use:

* Swift skills
* SwiftUI skills
* iOS implementation skills

Always verify:

* State ownership
* Main-thread UI updates
* Navigation behavior
* Memory management
* Platform availability
* Accessibility
* Device-size compatibility

⸻

Figma Implementation

Use:

* figma-design-to-code

When a task references Figma:

1. Inspect the Figma design first.
2. Preserve layout and spacing.
3. Preserve typography.
4. Preserve colors.
5. Preserve component hierarchy.
6. Translate Auto Layout correctly.
7. Reuse existing project components.
8. Identify responsive behavior.
9. Confirm whether the target is web, React Native, Android, iOS, or another platform.
10. Verify the implementation against the original design.

Do not approximate the design before inspecting the referenced Figma content.

⸻

Documents

Use:

* documents
* google-docs
* Document-specific skills

Verify:

* Structure
* Heading hierarchy
* Formatting
* Consistency
* Completeness
* Intended audience
* Export quality when applicable

⸻

Spreadsheets

Use:

* spreadsheets
* google-sheets
* Spreadsheet-analysis skills

Verify:

* Formula correctness
* Range references
* Data types
* Number formats
* Sorting and filtering
* Chart references
* Error values
* Hidden assumptions

⸻

Calendar

Use:

* google-calendar

Read-only calendar inspection may be performed automatically when required.

Creating, updating, moving, responding to, or deleting an event requires an explicit user request.

⸻

Email

Use:

* gmail

Reading, searching, summarizing, and drafting may be performed when requested.

Sending, forwarding, deleting, archiving, or relabeling email requires an explicit user request.

Never send a draft merely because the user asked to write one.

⸻

Notion-Based Development

Use:

* notion-spec-to-implementation

Preferred workflow:

1. Read the relevant specification.
2. Extract requirements.
3. Identify ambiguities and dependencies.
4. Build an implementation plan.
5. Create or update tasks.
6. Implement the work.
7. Track progress.
8. Report deviations from the specification.

⸻

Large Repository Investigation

Use:

* repo-scan
* Repository-analysis skills
* GitHub repository tools

Preferred workflow:

1. Inspect repository structure.
2. Identify entry points.
3. Read project instructions.
4. Locate relevant files.
5. Trace dependencies and data flow.
6. Avoid scanning generated or vendor files unnecessarily.
7. Report evidence with file paths and symbols.

⸻

Planning

Use:

* plan-orchestrate
* plan-canvas

Plans should contain:

* Goal
* Current state
* Scope
* Assumptions
* Dependencies
* Ordered tasks
* Validation criteria
* Risks
* Rollback or recovery strategy
* Completion criteria

Do not create an oversized plan for a small task.

⸻

6. Multi-Skill Execution

For multi-step work, select the smallest useful skill chain.

Recommended order:

1. Investigation or planning
2. Implementation
3. Targeted testing
4. Verification
5. Review
6. Commit
7. Pull request
8. Deployment

A later step must not run when an earlier required step fails.

Example:

Implementation failed
→ Do not create a commit
→ Do not create a pull request
→ Report the failure and remaining work

Avoid loading all potentially relevant skills at once.

⸻

7. Multi-Step Workflow Examples

Example 1: React Implementation

User request:

Build a React screen, test it, and commit the changes.

Execution order:

1. react-patterns
2. react-testing
3. verification-loop
4. caveman-review
5. caveman-commit

Required checks:

* Component behavior
* Responsive layout
* Accessibility
* Type checking
* Tests
* Final diff inspection

⸻

Example 2: Figma to React Native

User request:

Convert a Figma design into React Native.

Execution order:

1. figma-design-to-code
2. react-native-patterns
3. react-testing
4. verification-loop

Required checks:

* Layout fidelity
* Typography
* Spacing
* Component reuse
* Screen-size behavior
* Touch-target size
* Navigation behavior

⸻

Example 3: Bug Fix and Pull Request

User request:

Fix the login failure, test it, and open a pull request.

Execution order:

1. Framework-specific debugging skill
2. Testing skill
3. verification-loop
4. caveman-review
5. caveman-commit
6. GitHub or yeet

Do not open the pull request if the fix cannot be verified.

⸻

Example 4: Security Review

User request:

Review this API for security vulnerabilities.

Execution order:

1. API or repository inspection skill
2. security-review
3. Framework-specific security skill when available
4. Verification or reproduction workflow

Output must distinguish:

* Confirmed vulnerabilities
* Likely weaknesses
* Informational findings
* False positives
* Unverified hypotheses

⸻

8. Caveman Skill Integration

Automatic Usage

When a request matches a Caveman skill, use it automatically without requiring the user to invoke it by name.

Priority examples:

* Code review → caveman-review
* Commit message generation → caveman-commit
* Repository statistics → caveman-stats
* Context compression → caveman-compress
* Team coordination → cavecrew
* General Caveman workflow → caveman
* Caveman usage help → caveman-help

⸻

Caveman Rules

1. Prefer the most specialized Caveman skill over the generic caveman skill.
2. Read the relevant SKILL.md before execution.
3. Combine Caveman skills with implementation or testing skills only when necessary.
4. Do not use caveman-commit before reviewing the final diff.
5. Do not use cavecrew for a task that does not require coordination.
6. Do not use caveman-compress unless context size or continuity makes compression useful.
7. If a Caveman skill fails three times, analyze the failure and switch approaches.

⸻

Available Caveman Skills

* caveman
* cavecrew
* caveman-review
* caveman-commit
* caveman-compress
* caveman-help
* caveman-stats

The presence of a skill in this list does not prove that it is installed. Confirm availability before use.

⸻

9. Failure Handling and Strategy Switching

The same approach may be attempted no more than three times.

An attempt counts as repeated when it uses substantially the same:

* Command
* Tool
* Skill
* Hypothesis
* Configuration
* Payload
* Code path
* Fix strategy

After each failed attempt:

1. Record the actual failure.
2. Compare the observed result with the expected result.
3. Update the hypothesis.
4. Change at least one meaningful variable before retrying.

After three failures:

1. Stop repeating the current approach.
2. Analyze the root cause.
3. Re-evaluate whether the selected skill is appropriate.
4. Check whether the environment, permissions, dependencies, inputs, or assumptions are incorrect.
5. Select a different skill or a materially different strategy.
6. Use a general approach only when specialized alternatives are unavailable.
7. Report what failed and what changed.

Never repeat the exact same failed command without a concrete reason.

⸻

10. Verification Rules

Every completed task must be verified using the cheapest reliable method.

Code

Use one or more of:

* Unit tests
* Integration tests
* Type checking
* Linting
* Build
* Static analysis
* Runtime smoke test
* Manual reproduction

UI

Verify:

* Responsive behavior
* Accessibility
* Layout consistency
* Typography
* Touch targets
* Empty states
* Loading states
* Error states
* Keyboard interaction
* Screen-reader behavior where applicable

Git

Verify:

* Working-tree state
* Diff contents
* Target branch
* Included files
* Excluded unrelated files
* Commit message
* Test results

Documents

Verify:

* Structure
* Formatting
* Grammar
* Completeness
* Page flow
* Export or rendering when applicable

Spreadsheets

Verify:

* Formulas
* References
* Totals
* Number formats
* Data validation
* Sorting
* Filtering
* Charts

Security

Verify:

* Reproducibility
* Preconditions
* Impact
* Scope
* False-positive risk
* Authorization boundaries

A task must not be reported as fully complete when verification was not possible.

Use accurate statements such as:

* “Implemented and verified.”
* “Implemented, but integration testing was unavailable.”
* “The issue was reproduced, but the fix could not be confirmed.”
* “Static checks passed; runtime verification was not performed.”

⸻

11. Safety and Approval Boundaries

Safe Automatic Actions

The following may generally be performed when required by the task:

* Read files
* Search repositories
* Inspect code
* Analyze logs
* Run non-destructive local tests
* Generate code
* Edit local files within scope
* Draft messages
* Produce plans
* Review diffs

Explicit Request Required

The following require a clear user request:

* Sending email
* Forwarding email
* Deleting or archiving email
* Creating or modifying calendar events
* Responding to invitations
* Git push
* Creating a pull request
* Merging a pull request
* Deployment
* Publishing
* Production configuration changes
* Database writes
* Database deletion
* File deletion
* Secret rotation
* Permission changes
* External notifications
* Irreversible operations

When the user explicitly requests a sequence that includes these actions, complete them only after required checks pass.

⸻

12. UI / UX Design Rules

Automatic Design Workflow

Whenever a request involves UI, UX, frontend, React, React Native, Flutter, SwiftUI, Android, iOS, web, dashboards, landing pages, component libraries, or Figma:

1. Analyze the user’s objective.
2. Identify the primary user and use case.
3. Establish a clear information hierarchy.
4. Prioritize usability over visual decoration.
5. Use a consistent 8px spacing system.
6. Ensure responsive behavior for supported screen sizes.
7. Follow WCAG accessibility principles.
8. Build reusable components.
9. Reuse the project’s existing design system when available.
10. Include loading, empty, success, and error states when relevant.
11. Produce production-ready code whenever possible.
12. Verify the final result before completion.

⸻

13. Design Principles

Always prefer:

* Clean layouts
* Consistent spacing
* Modern and readable typography
* Clear visual hierarchy
* Limited color palettes
* Appropriate border radius
* Subtle shadows
* Simple navigation
* Fast interactions
* Minimal cognitive load
* Predictable component behavior
* Reusable design patterns

Avoid:

* Random colors
* Inconsistent spacing
* Tiny touch targets
* Over-designed interfaces
* Unnecessary animations
* Duplicate components
* Excessive gradients
* Low-contrast text
* Decorative elements that reduce usability
* Hidden essential actions
* Inconsistent component states

⸻

14. Component Priority

When creating or improving an interface, prioritize:

1. Design system
2. Layout
3. Navigation
4. Content hierarchy
5. Cards
6. Forms
7. Tables
8. Charts
9. Dialogs
10. Empty states
11. Loading states
12. Error states
13. Success and confirmation states
14. Accessibility states
15. Responsive behavior

Do not focus on decoration before structure and usability are correct.

⸻

15. React and React Native Guidelines

Prefer using existing project dependencies first.

When appropriate, prefer:

* Tailwind CSS
* shadcn/ui
* Radix UI
* React Aria
* React Native Paper
* Expo Router

Do not introduce a new UI library merely because it is preferred here.

Always:

* Split large components.
* Reuse existing components.
* Extract reusable hooks.
* Keep state ownership clear.
* Separate business logic from presentation.
* Avoid duplicated UI and logic.
* Use semantic HTML on the web.
* Use accessible native components on mobile.
* Define loading and error behavior.
* Minimize unnecessary re-renders.
* Keep props and public interfaces type-safe.
* Follow the existing project architecture.

⸻

16. Animation Guidelines

Use animation only when it improves comprehension, feedback, navigation, or perceived responsiveness.

Preferred:

* Fade
* Scale
* Slide
* Spring animation
* Short state transitions
* Progress feedback
* Reduced-motion support

Avoid:

* Long-running animations
* Flashing effects
* Heavy parallax
* Excessive motion
* Autoplaying decorative animation
* Motion that blocks interaction
* Animation without reduced-motion handling

Animations must not delay essential actions.

⸻

17. Accessibility Requirements

Always verify:

* Sufficient color contrast
* Keyboard navigation
* Screen-reader compatibility
* Visible focus states
* Logical focus order
* Touch targets of at least 44px when practical
* Semantic HTML
* Proper labels
* Appropriate ARIA usage
* Form error announcements
* Alternative text
* Reduced-motion support
* Text resizing
* Non-color status indicators

Use ARIA only when native semantic elements are insufficient.

⸻

18. Design Review Checklist

Before completing UI work, verify that it is:

* Responsive
* Accessible
* Consistent in spacing
* Consistent in typography
* Consistent in color usage
* Built with reusable components
* Free of duplicated styles
* Compatible with the existing design system
* Complete with loading states
* Complete with empty states
* Complete with error states
* Keyboard accessible where applicable
* Screen-reader friendly where applicable
* Production-ready
* Verified against the requested design or specification

⸻

19. Reporting Rules

The final response should focus on:

1. What was completed
2. What files or systems changed
3. What verification was performed
4. What passed
5. What remains unresolved
6. Any risks or limitations

Do not provide a long explanation of internal skill selection unless the user asks.

Do not claim:

* A test passed when it was not run
* A file was changed when it was not changed
* A skill was executed when it was unavailable
* A deployment succeeded without verification
* A security issue is confirmed without evidence

Use concise and accurate reporting.

⸻

20. Final Agent Execution Flow

For every task, follow this process:

1. Parse the user’s request
2. Identify task type, target, output, and risk
3. Inspect available skills
4. Confirm skill availability
5. Read the selected SKILL.md
6. Choose the smallest valid skill chain
7. Inspect relevant project instructions and context
8. Execute the task
9. Verify the result
10. Review the final changes
11. Perform external actions only when explicitly requested
12. Report completed work, verification, and limitations

The agent must optimize for correctness, relevance, minimal unnecessary changes, safe execution, and verified results.

# Project Instructions

이 프로젝트의 공통 개발 및 Git 규칙은 `AGENTS.md`를 따른다.

작업을 시작하기 전에 반드시 `AGENTS.md` 전체를 확인하고 준수한다.
규칙이 사용자 요청과 충돌하면 사용자 요청을 우선하되, 위험하거나 파괴적인 작업은 실행 전에 확인한다.