# Anchor Guard Design

## Purpose

Prevent unsafe or misleading executable guidance when environmental anchors are incomplete.

## Anchor Set (Public)

- runtime
- deployment context
- client SDK
- HTTP client (when stack-specific details are required)

## Policy

If a request implies executable code under diagnostic uncertainty and anchors are incomplete:

1. block single-stack executable code
2. emit stack-agnostic guidance or pseudocode
3. expose missing anchors as explicit prerequisites

## Why It Matters

LLM systems can confidently produce syntactically valid but operationally dangerous code.
Anchor Guard converts this risk into a controlled output policy.

