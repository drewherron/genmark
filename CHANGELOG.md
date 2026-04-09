# Changelog

All notable changes to Genmark are documented here.

## 0.2.0

### Added

- Plain-text spouse names on `m:` lines. Writing `m: Jane Doe` (instead of
  `m: [jane_doe]`) creates a single-parent FAM record with the known person
  as HUSB or WIFE and the unrecorded spouse as `1 NOTE Spouse: Jane Doe`.
  Children listed under the marriage attach to this FAM normally. When a
  date is included, it must be in parentheses to disambiguate it from a
  date-first marriage line: `m: Jane Doe (1915-06-20) @ Portland`.

  This brings spouse handling into line with the existing plain-text
  conventions for `parents:`, `>`, and `maybe:` — plain text is allowed
  anywhere a person reference would be a leaf at the edge of the tree.

## 0.1.0

Initial release. Compiles `.gmd` files to GEDCOM 5.5.1 with support for:

- Person records with life events, multiple marriages, divorce, and notes
- Defined sources, inline source citations, and person-level sources
- Top-down (`m:` + `>`), bottom-up (`parents:`), and standalone (`[a] + [b]`)
  family declarations with automatic merging
- Plain-text children, parents, and speculative (`maybe:`) links
- Recursive directory compilation with cross-file reference resolution
- Editor support for Emacs, Vim, and VS Code
