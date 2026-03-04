# Anchor Guard Design

## Purpose

Prevent unsafe or misleading executable guidance when environmental anchors are incomplete.

## Anchor Set (Public)

- runtime
- deployment context
- client SDK
- HTTP client (when stack-specific details are required)

## Anchor Completeness Scoring

Each anchor dimension contributes to a normalized score in `[0, 1]`.
Public default thresholds (replaceable in private deployments):

- `score < 0.50`: block executable code
- `0.50 <= score < 0.80`: allow pseudocode only
- `score >= 0.80`: executable output eligible (must still pass Quality Gate)

## Policy

If a request implies executable code under diagnostic uncertainty and anchors are incomplete:

1. block single-stack executable code
2. emit stack-agnostic guidance or pseudocode
3. expose missing anchors as explicit prerequisites

## Priority with Quality Gate

1. Anchor Guard runs first.
2. Quality Gate runs only after executable eligibility.
3. On conflict, stricter decision wins.

## Why It Matters

LLM systems can produce syntactically valid but operationally dangerous code.
Anchor Guard converts this risk into an explicit and auditable output policy.
