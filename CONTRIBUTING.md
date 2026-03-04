# Contributing

## Scope

This repository accepts contributions to:

- architecture documentation
- diagrams
- schema contracts
- pseudocode clarity
- benchmark methodology proposals

## Out of Scope

- requests for private runtime internals
- additions of local execution operators
- inclusion of sensitive production prompts/configuration

## Pull Request Checklist

1. No secrets or environment-specific identifiers.
2. No executable host-control code.
3. Contracts and diagrams remain internally consistent.
4. Changes include rationale and expected reliability impact.
5. Avoid meta-credibility or self-justifying wording in headings/body.
6. Run `./scripts/check-banned-phrases.sh` before opening a PR.
