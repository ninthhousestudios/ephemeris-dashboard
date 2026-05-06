# Issue tracker: Yojana

Yojana is the active issue tracker for this repo. All issue operations map to yojana MCP tool calls.

## Tool call mappings

### Create an issue

```
yojana_task action=create project="<slug>" title="<title>" description="<desc>"
  category="enhancement|bug|experiment"
  slice_type="AFK|HITL"
  acceptance_criteria=[{"text":"...","done":false}]
  tags=["<tag>",...]
```

New tasks start as `needs-triage`. Set fields you know; omit what you don't.

### Fetch a ticket

By human ID (preferred):
```
yojana_task action=get id="<project-slug>/<N>"
```

For a shaped context bundle:
```
yojana_context task="<project-slug>/<N>" shape="summary"
yojana_context task="<project-slug>/<N>" shape="working"
```

Use `summary` for quick status checks. Use `working` when you need acceptance criteria, decisions, neighbor context, and conversation history.

### List / query issues

```
yojana_query project="<slug>" status="<status>" category="<cat>" tag="<tag>"
```

All parameters are optional. Omit `project` for cross-project queries. Each result includes `ready` and `blocked` flags.

### Find ready tasks

```
yojana_ready project="<slug>"
```

Returns tasks with status `ready-for-agent` or `ready-for-human` where all `depends_on` targets are done. Omit `project` for cross-project.

### Apply a triage label

```
yojana_task action=update id="<project-slug>/<N>" status="<new-status>"
```

Valid statuses follow the triage label vocabulary (see `triage-labels.md`), plus execution states: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `in_progress`, `done`, `wontfix`.

Transitions are validated by the state machine — invalid transitions are rejected with an error.

### Update task fields

```
yojana_task action=update id="<project-slug>/<N>"
  title="..." description="..." acceptance_criteria=[...] decisions=[...]
  implementation_plan="..." context_refs=[...]
```

Partial updates — only include fields you're changing.

### Add a comment / conversation message

```
yojana_task action=comment id="<project-slug>/<N>" text="<message>" author="agent"
```

Appends to the task's conversation thread. Shows up in `working` context shape.

### Create dependency edges

```
yojana_edge action=create source="<uuid>" target="<uuid>" edge_type="depends_on"
```

Edge types: `depends_on`, `relates_to`, `supersedes`, `refines`, `motivated_by`. Cycle detection runs on `depends_on` edges.

### Delete an edge

```
yojana_edge action=delete id="<edge-uuid>"
```

### Publish a PRD

1. Create the project: `yojana_project action=create slug="<slug>" title="<title>"`
2. Create a task for the PRD itself with the decomposed issues as subsequent tasks
3. Wire dependencies with `yojana_edge`

## When a skill says "publish to the issue tracker"

Call `yojana_task action=create` with the appropriate project slug.

## When a skill says "fetch the relevant ticket"

Call `yojana_task action=get` or `yojana_context` with the task identifier. The user will normally pass the human ID (`project-slug/N`) or UUID.

## Spike and experiment conventions

To run a spike or experimental exploration:

1. **Create a spike project**: `yojana_project action=create slug="spike-<topic>" title="Spike: <topic>"`
2. **Log experiments as tasks** with `category="experiment"`:
   ```
   yojana_task action=create project="spike-<topic>" title="Experiment: <hypothesis>"
     category="experiment" description="<hypothesis and approach>"
     acceptance_criteria=[{"text":"<success criterion>","done":false}]
   ```
3. **Record results** via updates:
   - `execution_record` — what happened, raw observations
   - `decisions` — what was learned, conclusions drawn
   - Transition to `done` when the experiment is complete
4. **Synthesize**: query all tasks in the spike project (`yojana_query project="spike-<topic>"`) to review findings.
