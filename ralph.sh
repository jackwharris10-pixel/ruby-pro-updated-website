#!/bin/bash
# Ralph Wiggum Loop — Overnight autonomous coding agent
# Usage: ./ralph.sh [max_iterations]
#   nohup ./ralph.sh 30 > overnight.log 2>&1 &

cd "$(dirname "$0")"
unset CLAUDECODE  # Allow nested claude CLI calls

MAX_ITERATIONS=${1:-20}
MAX_RETRIES_PER_TASK=3
ITERATION=0
LAST_TASK_ID=""
TASK_RETRY_COUNT=0
TIMESTAMP=$(date '+%Y%m%d-%H%M')
SOURCE_BRANCH=$(git branch --show-current)

PROMPT='You are an autonomous coding agent working on the Ruby Pro Website (marketing site).

READ prd.json to get the task backlog.
READ progress.txt to see what previous iterations accomplished.
READ CLAUDE.md for project conventions and structure.

RULES:
1. Pick the FIRST task where "passes": false (skip any with "passes": "blocked")
2. Read all relevant files before making changes
3. Implement the task completely
4. Verify your work (check HTML structure, ensure consistent styling)
5. Update prd.json — set "passes": true for the completed task
6. Append to progress.txt: iteration number, timestamp, task ID+title, what you did, result
7. Git add the changed files and commit with a descriptive message prefixed with the task ID, e.g. "[Task 3] Add state JSON for OH, WA, VA"
8. If ALL tasks have "passes": true (or "blocked"), output the exact string RALPH_COMPLETE

IMPORTANT:
- Keep changes focused — one task per iteration
- Do not break existing functionality
- If a task is blocked or impossible, set "passes": "blocked" with a note, then move on
- This is a static HTML + Bootstrap 5 site hosted on Azure Static Web Apps
- Brand color: #681D15 (dark ruby). Secondary: #E5877D
- Every page needs: navbar, footer, GA tag (G-LC32W6VK7M), Apollo tracker
- State JSON files follow the pattern in assets/js/ga.json (why_ruby_pro, problem, difference, how_it_works)
- No build step — just edit HTML/CSS/JS/JSON directly'

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

# Create the overnight working branch
WORK_BRANCH="overnight/${TIMESTAMP}"
git checkout -b "$WORK_BRANCH"
log "Created working branch: $WORK_BRANCH (from $SOURCE_BRANCH)"

# Commit loop files so git clean won't delete them
git add -f ralph.sh morning.sh prd.json progress.txt 2>/dev/null
git commit -m "Add overnight loop files" --allow-empty 2>/dev/null || true

# Backup prd.json before we start
cp prd.json prd.json.backup

log "=== Ralph Wiggum Loop Started ==="
log "Max iterations: $MAX_ITERATIONS"
log ""

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))
    log "=== Iteration $ITERATION / $MAX_ITERATIONS ==="

    # Restore prd.json from backup if it got corrupted
    if ! python3 -c "import json; json.load(open('prd.json'))" 2>/dev/null; then
        log "WARNING: prd.json is corrupted, restoring from backup"
        cp prd.json.backup prd.json
    fi

    # Read the next task's model, ID, and title slug
    TASK_INFO=$(python3 -c "
import json, re
with open('prd.json') as f:
    data = json.load(f)
for t in data['tasks']:
    if t.get('passes') is False:
        slug = re.sub(r'[^a-z0-9]+', '-', t['title'].lower()).strip('-')[:40]
        print(t.get('model', 'sonnet'), t.get('id', '?'), slug)
        break
else:
    print('done 0 none')
" 2>/dev/null || echo "sonnet 0 unknown")

    TASK_MODEL=$(echo "$TASK_INFO" | awk '{print $1}')
    TASK_ID=$(echo "$TASK_INFO" | awk '{print $2}')
    TASK_SLUG=$(echo "$TASK_INFO" | awk '{print $3}')

    if [ "$TASK_MODEL" = "done" ]; then
        log "All tasks already complete!"
        break
    fi

    # Stuck detection: if same task fails 3 times, mark it blocked and move on
    if [ "$TASK_ID" = "$LAST_TASK_ID" ]; then
        TASK_RETRY_COUNT=$((TASK_RETRY_COUNT + 1))
        if [ $TASK_RETRY_COUNT -ge $MAX_RETRIES_PER_TASK ]; then
            log "WARNING: Task $TASK_ID failed $MAX_RETRIES_PER_TASK times, marking as blocked"
            python3 -c "
import json
with open('prd.json') as f:
    data = json.load(f)
for t in data['tasks']:
    if t.get('id') == $TASK_ID and t.get('passes') is False:
        t['passes'] = 'blocked'
        t['blocked_reason'] = 'Failed $MAX_RETRIES_PER_TASK consecutive attempts'
        break
with open('prd.json', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
            echo "Iteration $ITERATION — $(date) — Task $TASK_ID auto-blocked after $MAX_RETRIES_PER_TASK failures" >> progress.txt
            TASK_RETRY_COUNT=0
            LAST_TASK_ID=""
            continue
        fi
    else
        LAST_TASK_ID="$TASK_ID"
        TASK_RETRY_COUNT=1
    fi

    # Clean dirty state — only revert tracked files, never git clean
    if [ -n "$(git diff --name-only 2>/dev/null)" ]; then
        cp prd.json /tmp/ralph_prd_save.json 2>/dev/null || true
        cp progress.txt /tmp/ralph_progress_save.txt 2>/dev/null || true
        log "Reverting dirty tracked files"
        git checkout -- . 2>/dev/null || true
        cp /tmp/ralph_prd_save.json prd.json 2>/dev/null || true
        cp /tmp/ralph_progress_save.txt progress.txt 2>/dev/null || true
    fi

    # Create a per-task branch off the working branch so each task is isolated
    TASK_BRANCH="overnight/task-${TASK_ID}-${TASK_SLUG}"
    git branch -D "$TASK_BRANCH" 2>/dev/null || true
    git checkout -b "$TASK_BRANCH"

    # Snapshot prd.json before this iteration (so we can detect if task completed)
    cp prd.json prd.json.pre_iteration

    log "Task $TASK_ID — model: $TASK_MODEL — branch: $TASK_BRANCH"

    # Run Claude with a background timeout (15 min max per iteration)
    claude --print --dangerously-skip-permissions --model "$TASK_MODEL" \
        "$PROMPT" > /tmp/ralph_output.txt 2>&1 &
    CLAUDE_PID=$!

    # Wait up to 15 minutes
    WAIT_SECS=0
    while kill -0 $CLAUDE_PID 2>/dev/null; do
        sleep 10
        WAIT_SECS=$((WAIT_SECS + 10))
        if [ $WAIT_SECS -ge 900 ]; then
            log "WARNING: Iteration timed out after 15 minutes, killing"
            kill $CLAUDE_PID 2>/dev/null || true
            sleep 2
            kill -9 $CLAUDE_PID 2>/dev/null || true
            break
        fi
    done

    wait $CLAUDE_PID 2>/dev/null
    EXIT_CODE=$?
    OUTPUT=$(cat /tmp/ralph_output.txt 2>/dev/null || echo "")

    if [ $EXIT_CODE -ne 0 ] && [ -z "$OUTPUT" ]; then
        log "WARNING: Claude exited with code $EXIT_CODE"
        log "Cooling down 30s before next iteration..."
        git checkout "$WORK_BRANCH" 2>/dev/null
        sleep 30
        continue
    fi

    echo "$OUTPUT" | tail -20
    log ""

    # Check if prd.json was updated (task marked as done)
    TASK_COMPLETED=false
    if ! diff -q prd.json prd.json.pre_iteration >/dev/null 2>&1; then
        if python3 -c "import json; json.load(open('prd.json'))" 2>/dev/null; then
            cp prd.json prd.json.backup
            TASK_COMPLETED=true
            log "prd.json updated — task completed"
        fi
    fi

    # Merge the task branch back into the working branch
    if [ "$TASK_COMPLETED" = true ]; then
        git checkout "$WORK_BRANCH"
        git merge --no-edit "$TASK_BRANCH"
        log "Merged $TASK_BRANCH -> $WORK_BRANCH"
    else
        # Task didn't complete — discard the branch, go back to working branch
        git checkout "$WORK_BRANCH" 2>/dev/null
        git branch -D "$TASK_BRANCH" 2>/dev/null || true
        log "Task branch discarded (not completed)"
    fi

    if echo "$OUTPUT" | grep -q "RALPH_COMPLETE"; then
        log "=== ALL TASKS COMPLETE! ==="
        log "Total iterations: $ITERATION"
        break
    fi

    # Brief pause between iterations to avoid rate limits
    sleep 5
done

# Make sure we're on the working branch
git checkout "$WORK_BRANCH" 2>/dev/null || true

# Cleanup temp files
rm -f prd.json.backup prd.json.pre_iteration /tmp/ralph_output.txt /tmp/ralph_prd_save.json /tmp/ralph_progress_save.txt

log ""
log "=== Loop finished ==="

# Generate morning report
log "Generating morning report..."
./morning.sh > output/morning_report.html 2>/dev/null || true
log "Report saved to output/morning_report.html"

# Print the morning summary to terminal too
log ""
log "=== OVERNIGHT SUMMARY ==="
log "Working branch:  $WORK_BRANCH"
log "Source branch:   $SOURCE_BRANCH"
log "Iterations used: $ITERATION"
log ""
log "Task branches created (cherry-pick what you want):"
git branch --list "overnight/task-*" 2>/dev/null | while read -r b; do
    COMMIT_MSG=$(git log --oneline -1 "$b" 2>/dev/null | cut -d' ' -f2-)
    echo "  $b  —  $COMMIT_MSG"
done
log ""
log "Morning commands:"
log "  open output/morning_report.html                    # visual report"
log "  git log --oneline $SOURCE_BRANCH..$WORK_BRANCH     # all commits"
log "  git diff $SOURCE_BRANCH..$WORK_BRANCH --stat       # files changed"
log "  git cherry-pick <hash>                              # pick individual tasks"
log "  git merge $WORK_BRANCH                              # accept everything"
log "  git branch -D \$(git branch --list 'overnight/*')   # cleanup all overnight branches"
