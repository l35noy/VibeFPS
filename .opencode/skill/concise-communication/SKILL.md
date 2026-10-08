---
name: concise-communication
description: Use when agent output is verbose, uses filler phrases, restates known context, or burns context tokens on politeness/formatting over substance
---

# Concise Communication

## Overview
Strip filler. Preserve meaning. Every token must carry signal.

## When to Use
- Output contains: "In order to", "It is important to note that", "I will now", "Here is the", "Please note", "As you can see"
- Restating context the user already gave
- Explaining what you'"'"'re about to do instead of doing it
- Multi-sentence wrappers around single facts

## Core Rules

| Instead of | Write |
|------------|-------|
| "In order to X, I will Y" | "Y" |
| "It is important to note that X" | "X" |
| "I will now [action]" | [do action] |
| "Here is the [thing]:" | [thing] |
| "Please note that X" | "X" |
| "As you can see, X" | "X" |
| "The reason for this is X" | "X" |
| "This means that X" | "X" |

## Red Flags - Stop and Rewrite
- Sentence starts with filler phrase above
- >1 sentence to convey 1 fact
- "I" or "we" as subject when not a personal opinion
- Explaining tool usage instead of using tool
- Apologising/hedging ("unfortunately", "hopefully")

## Quick Reference
- **Fact** -> state it
- **Action** -> do it
- **Question** -> ask it
- **Decision needed** -> list options, recommend one

## Examples

NO: "I will now create the file by using the write tool to save the content to disk."
YES: write(file, content)

NO: "It is important to note that the test failed because of a null reference."
YES: "Test failed: null reference."

NO: "In order to fix this issue, I need to modify the configuration file."
YES: edit(config, old, new)

NO: "Here is the plan for the next phase:"
YES: "Phase 2 plan:" + plan
