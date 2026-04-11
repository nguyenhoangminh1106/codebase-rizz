---
name: learn-from-codebase
description: Weekly cron that picks one un-documented feature from the codebase and writes a narrative technical article about it — opened with a real human moment, grounded in direct PR/Slack quotes, structured around case studies, and ending on how the pattern generalizes. Saves to <data_dir>/articles/. Use when the user wants to deeply understand a feature, or let it run on schedule to build up a library of codebase knowledge.
---

# learn / from-codebase

Weekly cron. Every Sunday morning, pick one feature that hasn't been written about yet and produce a long-form technical blog post about it. This subskill is modeled closely on Hari's Zustand article — not a generic "explain this system" doc, but a narrative piece that opens with a real moment, teaches a diagnostic, walks through concrete case studies, and leaves the reader better at judging similar tradeoffs in their own code.

## Before doing anything

Run the preflight from `../_shared/paths.md` to resolve `<data_dir>`. As a multi-repo cron, iterate every entry in the registry and pick at most one feature per repo per run. Articles are always written to `<data_dir>/articles/`.

## Schedule

Default: Sunday 9:00am. Configured via `crons.from_codebase` and loaded as a launchd user agent by bootstrap. See `../_shared/crons.md`.

## Step 1 — Pick a feature

1. **List what's already covered.** Read every file in the articles output path. Scan the first heading of each; build a mental list of covered features. Do not pick anything in this list
2. **Identify candidates.** Good ones:
   - Recently merged non-trivial PRs (large diffs, multi-file, introduce new abstractions)
   - Subsystems with dedicated directories (`components_new/consolidated-messaging/`, `lib/services/*`)
   - Crons, background jobs, webhook handlers
   - State management, data flow, caching layers
   - Anything with an interesting disagreement in PR review history
3. **Prioritize features with a human story attached.** A feature that had a debate in its PR thread is much better source material than one that shipped quietly. The debate *is* the article
4. **Pick one.** Do not try to cover multiple features

If no candidate has a clear story behind it, skip this run and log "no candidate features with usable narrative hook found." Generic architecture explanations without a human moment are not the output this subskill is trying to produce.

## Step 2 — Research

Read the relevant files end-to-end. Not scanning — actually read. You need:

- **The entry point** where user interaction or external triggers start the flow
- **The data shape** — types, schemas, stores, payloads
- **The orchestration** — which functions call which, in what order, and with what guarantees
- **The non-obvious decisions** — why a store instead of a ref, why sessionStorage not localStorage, why this specific threshold

Then, separately and just as important:

- **Pull up the PR(s) that introduced the feature** via `gh pr list --repo <repo> --search "<feature name>"`. Read the PR descriptions, the review threads, and the commit messages. **Copy direct quotes verbatim** — reviewer nitpicks, author pushback, offhand comments that reveal what the team actually cared about. These are the heart of the article
- **Check if there's a Slack or ticket reference** in the PR description. If yes, try to get the source discussion (the user may have Slack context in their environment; if not, the PR thread is usually enough)
- **Look at who reviewed and approved.** If the persona files include any of those people, read their persona files too — their principles will shape the narrative voice

## Step 3 — Plan the article structure (explicit, before writing)

Don't jump to writing. Plan the structure first. Sketch out the headings in your scratch space and verify you have enough material to fill each one. If you can't think of anything specific for a section, that section doesn't exist in this article — don't pad.

**Mandatory sections** (in order):

1. **Opening hook: a specific moment.** A real exchange from a PR, a Slack thread, a decision point. Real names, real dates, real disagreement or surprise. *If you do not have a concrete moment to open with, stop and pick a different feature.* A generic problem statement as the opening is the single biggest failure mode of this subskill. The reader has to be pulled in by the first paragraph
2. **A diagnostic framework**, like Hari's "State Ladder" and "Three Smells." Teach the reader how to *recognize* the problem in their own code. This is what makes the article useful beyond the one feature it describes — without it, the article is a code walkthrough, not a teaching piece
3. **Case Study 1**: the main feature, deeply explained. Reference specific files with paths and line counts ("the file is 204 lines and this is the cleanest example of X in the repo"). Include a zoom-in on at least one specific function that demonstrates the principle — walk through its logic step by step, in prose, explaining *why each step is the way it is*
4. **Case Study 2** (if the feature has a related component that reinforces the principle): a second, smaller example. If no second example exists, replace this with a "When you'd reach for this elsewhere" section that gives concrete hypothetical uses
5. **Why this shape (and not the obvious alternatives).** This is the payoff section. Name the alternatives the team considered (or that a naive reader would reach for) and explain specifically why each one would fail. Use direct quotes from PR discussions where possible
6. **When this pattern generalizes.** One or two paragraphs about what else in the codebase could use the same approach, or what future features should default to this pattern

Optional sections, used only when they earn their place:

- **A Mermaid diagram** in the orchestration section if the flow genuinely needs one. Don't include diagrams for decoration — a diagram with 3 boxes and 2 arrows adds nothing
- **A "persistence" or "edge cases" callout** if the feature has subtle gotchas that deserve their own heading

## Step 4 — Write it

Now actually write. Keep these rules in mind throughout:

### Required elements in every article

1. **At least one direct quote** from a PR comment or commit message, woven into the prose. Attribute with author name and PR number. Example: `Minh's exact words: "dont wanna do 2 consecutive setState thats 2 render."`
2. **At least one specific measurement** — file line count, exact function name, exact file path with line number. Not "a large file" but "204 lines." Not "near the top" but "line 42." Concrete details anchor the reader
3. **A zoom-in section** on one function or code block, walked through step by step in prose
4. **The word "why"** at least three times in headings or section intros. If you can't find three whys, the article isn't ready — go back to research
5. **Mermaid diagram(s)** for any non-trivial flow. Use them for sequence diagrams, architecture diagrams, decision trees — things a paragraph couldn't convey as clearly

### Tone rules

- **Narrative, not reference.** "There was a Slack exchange on April 10 that is worth reading before you open any of the state management code" beats "This document describes the state management architecture"
- **Explain the *why*, not the *what*.** "It uses sessionStorage not localStorage" is the what. "It uses sessionStorage because the widget state is per-tab, and one tab's chat list should not stomp another's" is the why. Always write the why
- **Write like someone would read it cover to cover.** Not a wiki page the reader greps. A blog post that's worth someone's morning coffee
- **Don't apologize for the complexity.** If the feature is intricate, that's the story — lean into the intricacy, don't flatten it
- **Use the second person sparingly**, and only when it earns the attention ("you might try getting rid of the parts of the skill that are making it do that and seeing what happens")

### Length

Aim for **1500–3500 words**. Shorter and you're not going deep enough. Longer and the reader will bounce. If you're under 1500 when you finish, the structure is probably too shallow — go back and add a zoom-in or a case study 2. If you're over 3500, cut the least concrete section.

## Step 5 — Save

Save to `<data_dir>/articles/YYYY-MM-DD-<feature-slug>.md`. The slug should be short and human-readable (`frontend-state-with-zustand`, not `components_new_consolidated_messaging_widget`).

## Step 6 — Report

Tell the user:
- The feature picked and **why it was picked** (one sentence — what was the narrative hook?)
- A 2-sentence preview of the opening moment
- The path to the saved article
- Word count and section headings (so the user can sanity-check that the structure came out right)

## Anti-patterns — things that make the article fail

Do not produce articles that:

- Open with "This feature does X" or "This system handles Y" — that's the voice of reference documentation, not a blog post
- List functions in a bullet list without prose around them
- Explain *what* the code does without ever explaining *why*
- Skip the diagnostic section, turning the article into a code tour instead of a teaching piece
- Pad with Mermaid diagrams that a sentence would convey better
- Avoid direct quotes in favor of paraphrasing ("the team discussed this and decided X" — no, find the actual discussion and quote it)
- End with "In conclusion" or "This article explained" — the payoff should come through the structure, not an explicit recap

If an article would require any of these to exist, something earlier in the pipeline went wrong. Go back to Step 1 and pick a different feature — one with more usable material.

## Not this subskill's job

- Updating persona files (`learn/from-persona-code`)
- Deriving team patterns (`learn/from-pr-comments`)
- Suggesting refactors (`review`)

This one is purely about producing articles someone would actually want to read. A good article outlives any specific implementation — it captures the reasoning even after the code changes.
