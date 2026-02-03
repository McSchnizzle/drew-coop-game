# Drew's First Session: Shape the Game, Then Build It

**Drew — give this entire prompt to your Claude Code agent.**

---

## Hey Drew!

Welcome to the co-op game project! Before we write any code, I want to hear YOUR ideas about how this game should feel. You're not just watching — you're the designer making key decisions.

I'm going to:
1. Download the project your dad set up
2. Show you what's planned so far
3. Ask you questions about how you want the game to feel
4. Update the design docs based on your answers
5. Then build the first playable version together

Let's go!

---

## Step 1: Get the Project

First, I'll clone the repository. Run this:

```bash
cd ~/Desktop
git clone https://github.com/McSchnizzle/drew-coop-game.git
cd drew-coop-game
```

---

## Step 2: Read What's Planned

Read these files to understand the current plan:
- `/docs/game-spec-drew.md` — The full game design
- `/docs/GOLDEN_PATH.md` — What we're building first

After reading, give Drew a quick summary:
- It's a 2-player co-op shooter
- You fight "Merge Conflict" enemies that split when you kill them wrong
- You have a "Git Revert" beam that kills them cleanly (no split)
- Phase 1 is side-scrolling (like Contra), 16-bit pixel art style
- First build: get two players moving, shooting, and killing one enemy

---

## Step 3: Ask Drew These Questions

**Ask these one at a time. Wait for Drew's answer before moving on.**

### Question 1: Movement Feel

How should your character move?

**A) Floaty/Moon-like** — Big jumps, slow fall, feels like Mega Man
**B) Snappy/Heavy** — Quick jumps, fast fall, feels like Contra or Celeste
**C) Somewhere in between** — Medium jumps, normal gravity

What sounds more fun to you?

---

### Question 2: Player Speed

How fast should the player run?

**A) Fast** — Zoom across the screen, action-packed
**B) Medium** — Balanced, time to react
**C) Slow** — Careful, tactical movement

---

### Question 3: Placeholder Colors

While we build the first version, we'll use colored rectangles instead of real art. What colors do you want?

**Player 1:** (suggest: Blue? Green? Pick any color)
**Player 2:** (suggest: different color so you can tell apart)
**Enemy:** (suggest: Red? Orange? Something that says "danger")
**Projectiles:** (suggest: Yellow? White? Something bright)

---

### Question 4: Jump Controls

When you press jump, should you be able to:

**A) Single jump only** — One jump, that's it (classic Contra)
**B) Double jump** — Jump once, then jump again in mid-air (more mobility)
**C) Variable jump** — Hold jump to go higher, tap for short hop

---

### Question 5: Shooting Style

How should shooting work?

**A) Tap to shoot** — Each button press = one shot
**B) Hold to auto-fire** — Hold the button, bullets keep coming
**C) Both** — Tap for single shots, hold for rapid fire

---

### Question 6: First Test Wave Count

For the first playable version, how many waves of enemies before you "win"?

**A) 3 waves** — Quick test, see if it's fun fast
**B) 5 waves** — Medium session
**C) 10 waves** — Full experience

(We can always change this later!)

---

### Question 7: What's Most Important To You?

When you play this first version with your dad, what do you MOST want to feel?

**A) "This controls feel GOOD"** — Smooth movement, satisfying shooting
**B) "This is HARD but fair"** — Enemies are challenging, dying teaches you
**C) "We have to work TOGETHER"** — Can't win without teamwork
**D) Something else** — (Tell me what!)

---

### Question 8: Any Other Ideas?

Is there anything else you want in this first version? Any ideas bouncing around in your head?

(Even if it sounds too big for now, tell me — we can plan for later!)

---

## Step 4: Update the Docs

Based on Drew's answers, update these files:

### Update `/docs/game-spec-drew.md`

Find the Phase 1 table and add/modify:
- Movement feel (floaty/snappy/medium)
- Player speed (fast/medium/slow)
- Jump style (single/double/variable)
- Shooting style (tap/hold/both)

Find Section 13 "Open Questions for Drew" and move answered questions to a new section "Drew's Decisions" with his answers.

### Update `/docs/GOLDEN_PATH.md`

Add a "Drew's Preferences" section near the top with:
```markdown
## Drew's Preferences (from first session)
- Movement: [his answer]
- Speed: [his answer]
- Jump: [his answer]
- Shooting: [his answer]
- Placeholder colors: Player 1 = [X], Player 2 = [Y], Enemy = [Z], Projectile = [W]
- Test waves: [number]
- Priority feel: [his answer to Q7]
```

### Update `/docs/agent_prompts/GOLDEN_PATH_BUILD.md`

Find the placeholder colors section and update with Drew's color choices.

Add physics guidance based on his movement/jump answers:
```markdown
## Drew's Movement Preferences
- Feel: [floaty/snappy/medium]
- Jump: [single/double/variable]
- Speed: [fast/medium/slow]
- Shooting: [tap/hold/both]

Tune these values to match:
- Gravity: [suggest value based on feel]
- Jump velocity: [suggest value based on feel]
- Run speed: [suggest value based on speed choice]
```

---

## Step 5: Commit Drew's Decisions

```bash
git add -A
git commit -m "Add Drew's design decisions from first session

Drew chose:
- [Movement feel]
- [Jump style]
- [Shooting style]
- [Color scheme]
- [Wave count]
- [Priority: what matters most]

Co-Authored-By: Drew <drew@drew-coop-game.local>
"
git push
```

---

## Step 6: Build the Golden Path

Now that Drew has shaped the design, build the game!

Read `/docs/agent_prompts/GOLDEN_PATH_BUILD.md` and follow its instructions, incorporating Drew's preferences into the physics and visuals.

**Important:** As you code, explain to Drew what you're doing. He should understand:
- "Now I'm making the player move left and right"
- "This is the code that makes bullets fire"
- "This connects two computers together"

If Drew has questions or wants changes, listen and adapt.

---

## Step 7: Test Together

Once the build is ready:
1. Export the game (or run two editor windows)
2. Drew's dad hosts
3. Drew joins
4. Play together!
5. Talk about what feels good and what needs tweaking

---

## Remember

Drew — this is YOUR game too. If something doesn't feel right, speak up! We can change anything. The whole point of this first version is to find out what's fun.

Have fun building! 🎮
