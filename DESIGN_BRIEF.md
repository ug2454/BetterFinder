# BetterFinder — Figma design and approval brief

Status: Figma connected. [First explorer frame](https://www.figma.com/design/mXjXSk7SYQ2NGIspwaoFID?node-id=3-2) is partially constructed; Figma Starter MCP call limit blocked completion and visual verification. This remains a design brief, not a completed or approved design package. See FIGMA_STATE.json for exact progress.

## Design objective

Make folder navigation as explicit as Windows Explorer while delivering a calm native Mac experience. Favor a readable file list, visible hierarchy, and predictable actions. Use SPEC.md as the behavior contract.

## File organization

1. **00 · Read me** — product promise, scope, legend, prototype starting points, revision and approval record.
2. **01 · Directions** — two comparable main-window concepts: recommended Quiet Precision (graphite/porcelain, muted blue), and Warm Studio (warmer neutrals, softer chrome). Keep structure and fixture data identical so styling is easy to compare.
3. **02 · Foundations** — semantic color variables with light/dark modes; type; spacing; density; radii; icon rules; focus and selection.
4. **03 · Components** — auto-layout component sets and interaction states.
5. **04 · Explorer** — high-fidelity browse, preview, split-pane, and responsive layouts.
6. **05 · Operations** — transfer queue, conflict sheets, errors, recovery, rename.
7. **06 · Search and organization** — search, filters, batch rename, workspaces, preferences.
8. **07 · Prototype** — connected end-to-end task flows.
9. **08 · Handoff** — approved frames, behavior annotations, measurements, assets, unresolved issues.

## Component inventory

Window chrome; tab active/inactive/hover/overflow; toolbar icon button; segmented view control; breadcrumb segment; editable path; search field and scope control; sidebar section/tree row; details header/row; icon tile; inspector field; badge/tag; status bar; transfer card; conflict comparison; dialog; toast; empty/error/loading panel; split divider.

For interactive components include default, hover, pressed, focused, disabled, selected, and inactive-selected where applicable. Include folder disclosure, rename editing/error, drop-valid/drop-invalid, thumbnail loading/unavailable, and accessible error labels. Use auto layout and semantic variables; avoid flat screenshot-only deliverables.

## Required review screens

| ID | Screen | Required details |
| --- | --- | --- |
| D01 | Main explorer, dark, 1440×960 | Folder tree, 3 tabs, breadcrumb, detailed rows, single selection, inspector. |
| D02 | Main explorer, light, 1440×960 | Same data and geometry as D01 for comparison. |
| D03 | Compact density, 1280×800 | More visible rows; readable metadata and focus state. |
| D04 | Minimum width, 960×640 | Inspector collapsed; toolbar overflow; truncated names with discoverable full paths. |
| D05 | Icon view | Mixed files, thumbnail loading/fallback, multiple selection. |
| D06 | Split panes | Different locations, clear active pane, pane-specific tabs/paths, explicit drag destination. |
| D07 | Search | Scope, active filters, location column, in-progress and incomplete-index states. |
| D08 | Transfer center | Queued/running/completed/partial-failure cards; progress and cancellation. |
| D09 | File collision | Source/destination comparison; Skip/Keep Both/Replace/Cancel; scoped apply-to-remaining. |
| D10 | Folder collision | Explicit merge explanation and handling of nested conflicts. |
| D11 | Rename and batch rename | Inline validation plus batch before/after preview with conflicts. |
| D12 | Permission and unavailable volume | Clear recovery actions; preserved location and session. |
| D13 | Empty/loading/no results | Three distinct states with appropriate actions. |
| D14 | Quick Look and inspector | Selected item context, unsupported-preview fallback, keyboard dismissal. |
| D15 | Preferences and first launch | Appearance, density, shortcuts, startup; location access only when needed. |
| D16 | Interrupted operation recovery | Completed/remaining/failed item summary; explicit retry; no automatic destructive replay. |

Use fictional fixtures only: Home → Projects → Northstar; folders Assets, Exports, Research; files Brand guidelines.pdf, Homepage.fig, Notes.md, hero-light.png, project.json; external drive Studio SSD. Dates, file counts, selected totals, and transfer totals must agree across linked frames.

## Clickable approval flows

1. **Find and open:** favorite → tree expansion → folder → sort → select → Space preview → open.
2. **Move with confidence:** split panes → multi-select → move → collision → Keep Both → completion → inspect destination.
3. **Search and return:** scoped search → kind/date filters → result → containing folder → back to prior state.
4. **Organize:** select files → batch rename → invalid result → correct rule → preview → Apply → completion.
5. **Recover:** begin transfer → destination unavailable → partial results → reconnect → explicitly retry failed items.

Figma represents states and transitions with fixture data; it does not demonstrate real filesystem correctness. Document keyboard behavior even where prototype tooling cannot reproduce it accurately.

## Review and approval protocol

Present the main dark/light windows and split-pane flow first, followed by operation/conflict states. Provide a Figma file link and exact named frame/revision references. Ask the user to approve the concrete design or request changes; do not ask them to approve an abstract description in place of a design.

Approval checklist:

- Main layout, visual direction, typography and density feel right.
- Path/tree/tabs make current location obvious.
- Selection and active split pane are unmistakable.
- Copy versus move and collision choices are understandable.
- Light, dark, and minimum-window designs are usable.
- Core prototype flows and essential error states are reviewed.

Record: revision, approved frame IDs/links, approval date, user response, outstanding scope exclusions. Production implementation stays pending until explicit approval.

## Handoff requirements

Provide editable frames, reusable components/variables, layout constraints, icon sources, copy, interaction/state annotations, keyboard map, accessibility notes, and a frame-to-requirement mapping. Avoid implying that prototype animation or decorative effects are required where native behavior is more appropriate.
