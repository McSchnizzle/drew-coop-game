# Checkpoint Process

## When to Checkpoint

- After significant progress on any lane (2-3 sessions per lane)
- Before any major interface change
- When any lane is blocked waiting on another
- At least once per week during active development

## Checkpoint Steps

### 1. Review Lane Status Files

Read each `LANE_STATUS.md`:
- `/game/lane_a_networking/LANE_STATUS.md`
- `/game/lane_b_combat/LANE_STATUS.md`
- `/game/lane_c_art/LANE_STATUS.md`

Note:
- What's complete in each lane
- What's blocked
- Any interface change proposals

### 2. Review Interface Change Proposals

If any lane proposed changes to:
- `/docs/interfaces/game_events.md`
- `/docs/interfaces/entity_schema.md`

Decide:
- Accept the change → update the interface file
- Reject → document why in lane's status file
- Modify → update with revised version

### 3. Create Integration Branch

```bash
git checkout main
git pull
git checkout -b integration/checkpoint-YYYY-MM-DD

# Merge each lane
git merge lane-a/networking
git merge lane-b/combat
git merge lane-c/art
```

### 4. Resolve Conflicts

If merge conflicts:
- Interface files: defer to the agreed changes from step 2
- Lane-specific files: each lane's version is authoritative for their folder
- Shared files (main scene, project.godot): manual resolution

### 5. Integration Test

Run the game and verify:
- [ ] Host can create lobby
- [ ] Client can join
- [ ] Players appear on both screens
- [ ] Enemies spawn and are visible to both
- [ ] Shooting works and damage syncs
- [ ] Abilities trigger and sync
- [ ] Wave progression works
- [ ] Win/lose conditions trigger correctly

### 6. Fix Integration Issues

If issues found:
- Determine which lane owns the fix
- Create fix on that lane's branch
- Re-merge to integration branch
- Re-test

### 7. Merge to Main

Once integration tests pass:
```bash
git checkout main
git merge integration/checkpoint-YYYY-MM-DD
git push origin main
```

### 8. Update Lane Branches

Each lane should rebase on new main:
```bash
git checkout lane-a/networking
git rebase main
git push -f origin lane-a/networking
```

### 9. Reset Lane Status Files

Clear the "Completed This Session" sections in each `LANE_STATUS.md` to prepare for next development cycle.

---

## Interface Change Protocol

Changes to interface contracts require agreement because they affect all lanes.

### Small Changes (new event, new field)
- Proposing lane documents in `LANE_STATUS.md`
- At checkpoint, if no objections, add to interface file
- All lanes adapt

### Breaking Changes (rename, remove, restructure)
- Proposing lane documents with rationale
- At checkpoint, explicit discussion required
- If approved: update interface, all lanes adapt in same checkpoint
- If rejected: proposer finds alternative approach

### Emergency Changes (mid-cycle)
- Only if a lane is completely blocked
- Document in `LANE_STATUS.md` with "URGENT" tag
- Notify other lanes (they may need to pause)
- Make minimal change to unblock
- Full review at next checkpoint
