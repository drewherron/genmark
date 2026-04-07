# Genmark Syntax Reference

Genmark is a plain-text language for writing genealogical data. It compiles
to GEDCOM 5.5.1, the standard interchange format for genealogy software.

Genmark files use the `.gmd` extension. This document describes the correct
syntax of a `.gmd` file. The intent is that the Genmark language stands on
its own and no knowledge of GEDCOM is necessary to use it. There is some
information in this guide about how Genmark actually maps to GEDCOM, but
you can safely ignore that if you want to.

---

## File Structure

A `.gmd` file contains three kinds of top-level blocks, in any order:

- **Person records** (`Full Name [id]`)
- **Source definitions** (`source [id]`)
- **Standalone unions** (`[id] + [id]`)

A block starts at its header line (column 0, no indentation) and includes
everything indented below it. Blank lines within indented content are part
of the block; a blank line followed by unindented content ends it.
Unindented comments directly above a header (with no blank line between)
are also considered part of that block. Unindented comments separated from
any block by blank lines are standalone -- useful as section markers in
longer files.

Multiple `.gmd` files can be compiled together into a single GEDCOM output.
References between files are resolved automatically. This allows you to organize
your genealogical data however you want.

---

## Person Records

A person record starts (at column 0, no indentation) with a display name, then a
unique ID in square brackets. Any fields for that person are placed on indented
lines following that initial line.

```
Jane Elizabeth Doe [jane_doe]
  sex: F
  b: 1892-08-12 @ Boston, Massachusetts
  d: 1965-11-03 @ Queens, New York
```

Not all fields are required. Even a record with no fields at all is valid and
useful as a stub - for example, a spouse you only know by name:

```
John Doe [john_doe]
```

The `?` character has special meaning in two places: `sex: ?` marks sex as
unknown (omitted from GEDCOM output), and `d: ?` means "known to be deceased,
no details" (compiles to `1 DEAT Y`). On other event fields, `?` is valid as
a date expression meaning "unknown date," but in practice it's equivalent to
simply omitting the date.

Three fields can appear only once per person: `sex`, `b`, `d`. The rest are
allowed to appear multiple times (although it may not make much sense in
some cases).

### Identity Fields

```
aka: Alternate Name
```

Multiple `aka:` lines are allowed. Each produces an additional GEDCOM NAME tag.

```
sex: M / F / ?
```

`sex: ?` is omitted from GEDCOM output (GEDCOM allows absent SEX).

### Life Events

Event fields come in two forms depending on whether the line starts with a
date or a description.

**Date-first fields** (`b`, `d`, `chr`, `bap`, `bur`, `crm`, `imm`, `emi`,
`nat`, `res`, `cen`) follow the pattern `tag: date @ place`:

```
b: 1888 @ London                // date and place
b: 1888                         // date only
b: @ London                     // place only
```

Date and place are individually optional. The `@` marker is required whenever a
place is present. The parser splits on `@`: everything left of it is the date,
everything to the right is the place.

| Tag    | Meaning           | GEDCOM Tag |
|--------|-------------------|------------|
| `b:`   | Birth             | `BIRT`     |
| `d:`   | Death             | `DEAT`     |
| `chr:` | Christening       | `CHR`      |
| `bap:` | Baptism           | `BAPM`     |
| `bur:` | Burial            | `BURI`     |
| `crm:` | Cremation         | `CREM`     |
| `imm:` | Immigration       | `IMMI`     |
| `emi:` | Emigration        | `EMIG`     |
| `nat:` | Naturalization    | `NATU`     |
| `res:` | Residence         | `RESI`     |
| `cen:` | Census            | `CENS`     |

**Description-first fields** (`occ`, `mil`, `evt`) follow the pattern:
`tag: description (date) @ place`.

These fields start with descriptive text. If a date is included, it goes in parentheses:

```
occ: Carpenter (1910..1920) @ London
mil: US Army (1945..1947)
evt: Naturalization (1918-03-15) @ Brooklyn, NY
```

The consistent rule: **if a date follows descriptive text on the same line,
it must be in parentheses.** This removes ambiguity between descriptions
that contain numbers and actual dates. If the value starts with a date,
parentheses should not be used.

### Occupation

```
occ: Farmer
occ: Carpenter @ London
occ: Factory Foreman (1921..1945) @ New York, NY
```

The occupation name goes before `@`. An optional date range in parentheses
indicates the period the occupation was held. Multiple `occ:` lines are
allowed.

### Military Service

```
mil: US Army, WWI
mil: US Army (1945..1947), Military Police
```

Free-form description, with an optional date in parentheses. Compiles to
`1 EVEN` with `2 TYPE Military Service`.

### Generic Events

```
evt: Graduated summa cum laude (1942-06) @ Columbia University, New York
```

For events without a dedicated tag. The description precedes the date.
Compiles to `1 EVEN` with `2 TYPE <description>`.

---

## Relationships

### Marriage

```
m: [spouse_id] date @ place
  > [child_id]
  > [child_id] (adopted)
ff```

Children are listed with `>` indented under the marriage. Child modifiers:

| Modifier       | GEDCOM PEDI              |
|----------------|--------------------------|
| `(adopted)`    | `ADOPTED`                |
| `(step)`       | `STEP`                   |
| `(foster)`     | `FOSTER`                 |
| `(stillborn)`  | *(note on child record)* |
| `(died young)` | *(note on child record)* |

A person may have multiple `m:` lines for multiple marriages. Children
listed under each `m:` are attached to that specific marriage:

```
m: [first_spouse] 1960
  > [child_from_first]
m: [second_spouse] 1975
  > [child_from_second]
```

### Divorce

```
div: [spouse_id] date @ place
```

Date and place are optional. The compiler attaches the divorce to the
corresponding family record.

### Parents (Bottom-Up)

Link a person to their parents:

```
parents: [father_id], [mother_id]
parents: [father_id], [mother_id] (adopted)
```

This creates or merges the same family record that the parents' `m:` line
would create. Both directions are equivalent and can coexist.

### Speculative Links

```
maybe: brother [id]
maybe: father [id]
maybe: parents [id], [id]
```

Speculative links are **not emitted to GEDCOM**. They exist for the
researcher's benefit and can be reviewed with `genmark check`. You can
use any text for the relationship label.

---

## Plain-Text References

Square brackets create a link to a defined record. When you omit the
brackets, the text is treated as a plain name with **no record linkage**.
The compiler emits it as a `NOTE` in GEDCOM instead of a structural
reference. No person or family record is created.

This is useful at the edges of the tree - people you know by name but
don't intend to track as full records.

### Parents

```
parents: Edward Smith, Mary Johnson
```

Emits as `1 NOTE Parents: Edward Smith, Mary Johnson` on the person's
GEDCOM record. No family record is created. Compare with the linked form
`parents: [edward], [mary]`, which creates or merges a FAM record.

### Spouse

```
m: Jane Doe
m: Jane Doe (1915-06-20) @ Portland, Oregon
  > [robert_doe]
```

When the spouse is a plain-text name instead of an `[id]` reference, the
compiler creates a single-parent FAM record (with the known person as
HUSB or WIFE) and writes the unrecorded spouse as `1 NOTE Spouse: Jane
Doe` on that FAM. Children listed under the marriage attach to this
single-parent FAM normally.

If the line includes a date, it must be enclosed in parentheses — same
rule used by `occ:`, `mil:`, and `evt:` to disambiguate descriptive text
from a leading date.

### Children

```
m: [spouse_id]
  > [alice_doe]
  > Robert Doe
  > William Doe (adopted)
```

Linked children (with brackets) get `1 CHIL` references on the FAM record.
Plain-text children emit as `1 NOTE Child: Robert Doe` on the FAM record.

### Speculative Links

```
maybe: brother [id]
maybe: cousin John Doe
```

Since `maybe:` links are not emitted to GEDCOM, plain text works naturally
here — the text is simply stored for the researcher's reference.

---

## Standalone Unions

For couples where you prefer not to embed the family under either spouse,
or for unmarried partnerships:

```
[john_doe] + [jane_smith]
  m: 1968-05-20 @ Portland, Oregon
    > [child_id]
```

The `m:` line is optional (omit it for unmarried partnerships). Children
listed directly under the union header (without `m:`) belong to the couple
without a marriage event.

The compiler merges union blocks with any matching `m:` or `parents:`
declarations elsewhere in the file.

---

## Date Expressions

```
1888-05-15     exact date (YYYY-MM-DD)
1888-05        year and month (YYYY-MM)
1888           year only
~1888          approximate              ABT 1888
<1888          before                   BEF 1888
>1888          after                    AFT 1888
1888..1895     range                    BET 1888 AND 1895
?              unknown / unspecified
```

Modifiers `~`, `<`, `>` combine with partial dates: `~1888-05` means
"approximately May 1888."

Modifiers do **not** combine with ranges. A range already implies uncertainty.
Write `1843..1846`, not `~1843..1846`.

Parenthesized date ranges on `occ:` lines are contextual periods, not event
dates:

```
occ: Carpenter (1910..1920) @ London
```

This means "occupation held during 1910-1920," not "occupation event on that
date."

---

## Source Citations

Genmark has three tiers of source usage, corresponding to research maturity.

### 1. Defined Sources

Declare a source once with full metadata, then reference it by ID:

```
source [src_1920_census]
  title: 1920 United States Federal Census
  repo: National Archives, Washington, D.C.
  url: https://www.familysearch.org/ark:/61903/1:1:ABCD
  note: Accessed via FamilySearch, January 2024
```

Available fields: `title`, `author`, `pub`, `url`, `repo`, `page`, `note`.

Reference it on any fact line with `[src: id]`:

```
b: 1892-08-12 @ Boston, MA  [src: src_1920_census]
chr: 1888-06 @ London       [src: src_stmarks, p. 142]
```

The optional text after the comma is a detail (page number, entry, etc.).

### 2. Inline Fact-Level Sources

For one-off citations that don't merit a full source definition:

```
b: 1892-08-12 @ Boston, MA  [src: Boston Birth Records, Vol 2, p. 14]
```

The compiler distinguishes defined source references from inline text by
checking whether the content matches a defined source ID.

### 3. Person-Level Sources

Bare `src:` lines attach a source to the person as a whole, without tying
it to a specific event:

```
John William Doe [john]
  b: 1916-04-02 @ Brooklyn, NY
  src: https://www.findagrave.com/memorial/12345/john-doe
  src: Portland City Directory, 1948, p. 212
```

These compile to `1 SOUR` with `2 NOTE` under the GEDCOM `INDI` record.

**Potential Workflow**: dump a link now with bare `src:`, attach it to a fact later
with inline `[src:]`, and promote it to a full defined source when multiple
people reference it.

---

## Comments

Both comment forms are **completely ignored** by the compiler. They never
appear in GEDCOM output.

```
// Single-line comment

/* Block comment.
   Can span multiple lines.
   Use for raw source material: obituaries, census
   transcriptions, research notes. */
```

Comments are for the human reader. Use `note:` for text that should compile
to GEDCOM.

**Recommended approach for rich biographical data:**

1. Structured facts go in proper fields (`b:`, `res:`, `mil:`, `occ:`, etc.)
2. Biographical context that belongs in the record goes in `note:` (compiles to GEDCOM NOTE)
3. Raw source material (full obituary text, census transcriptions) goes in `/* block comments */` (ignored by compiler)

### Comments and Blocks in Editors

Comments directly above a record header (with no blank line between), and everything
indented below it (regardless of blank lines), are considered part of that block for
folding and movement in the Emacs mode. Unindented comments separated from records by blank lines
are standalone -- they stay visible when blocks are folded and can be used as section
markers. See [editor/EDITORS.md](editor/EDITORS.md) for details.

Currently this block definition only applies to Emacs, but it's good to follow this
standardized convention (knowing when blank lines and indents define a block). This
behavior will be expanded to other editors in the future when/where possible.

### URLs in Comments

Comment markers `//` and `/*` are only recognized when preceded by whitespace
or at the start of a line. This prevents `://` in URLs from being treated as
a comment:

```
src: https://www.example.com/page   // this is a comment

note: Such useful information//this is not a comment
```

---

## Notes

Single-line:

```
note: Family bible lists a middle name of "Washington" but no documents confirm this.
```

Multi-line (pipe syntax):

```
note: |
  Ship manifest not yet located. Family story says he
  lost two fingers in a carpentry accident around 1912.

  Possibly the "J. Doe" listed in the 1910 NYC
  directory as a boarder at 14 Mott Street.
```

Everything indented beneath the `|` belongs to the note. Blank lines within
are preserved. The block ends when indentation returns to the enclosing level.

---

## IDs

IDs appear in square brackets: `[john_doe]`, `[src_1920_census]`.

- On a header line, brackets define the ID. Everywhere else, they reference it.
- Forward references are valid: you can reference `[jane]` in a marriage line
  before Jane's record appears in the file.
- Must be unique across *all* compiled files.
- User-chosen short handles, not auto-generated. Convention encourages contextual IDs
like `[john_chicago]` or `[grandpa_john]` or `[john_doe_1920]` over `[john_doe_1]`, but
that's entirely up to the user.
- An undefined reference is an error at compile time (except in `maybe:` lines, which produce warnings).

---

## Family Merging

Families can be declared from multiple directions, and the compiler merges
them into a single GEDCOM FAM record:

1. **Top-down**: `m: [spouse]` with `> [child]` lines on a person record
2. **Bottom-up**: `parents: [id], [id]` on a child's record
3. **Standalone**: `[id] + [id]` union block

All three can coexist. If both spouses declare the same marriage, or a child's
`parents:` line matches an existing couple, the compiler unifies them. If
details conflict (different dates or places), the compiler warns.

---

## Name Handling

The display name on the header line is free-form. The compiler extracts the
surname using a last-word heuristic:

```
John Arthur Doe [john]     -->  GEDCOM: John Arthur /Doe/
```

Common suffixes are recognized and placed after the surname rather than
being treated as part of it. Recognized suffixes: Jr., Sr., I, II, III,
IV, V, Esq.

```
John Doe Sr. [john_sr]     -->  GEDCOM: John /Doe/ Sr.
```

---

## GEDCOM Mapping Reference

| Genmark               | GEDCOM 5.5.1                               |
|-----------------------|--------------------------------------------|
| `Full Name [id]`      | `0 @I_id@ INDI` + `1 NAME Given /Surname/` |
| `aka:`                | Additional `1 NAME` tags                   |
| `sex: M/F`            | `1 SEX M/F`                                |
| `b:`                  | `1 BIRT`                                   |
| `d:`                  | `1 DEAT`                                   |
| `chr:`                | `1 CHR`                                    |
| `bap:`                | `1 BAPM`                                   |
| `bur:`                | `1 BURI`                                   |
| `crm:`                | `1 CREM`                                   |
| `imm:`                | `1 IMMI`                                   |
| `emi:`                | `1 EMIG`                                   |
| `nat:`                | `1 NATU`                                   |
| `res:`                | `1 RESI`                                   |
| `cen:`                | `1 CENS`                                   |
| date                  | `2 DATE` (with ABT/BEF/AFT/BET..AND)       |
| `@ place`             | `2 PLAC`                                   |
| `[src: id]`           | `2 SOUR @S_id@`                            |
| `[src: text]`         | `2 SOUR` + `3 TEXT`                        |
| `occ:`                | `1 OCCU`                                   |
| `mil:`                | `1 EVEN` + `2 TYPE Military Service`       |
| `evt:`                | `1 EVEN` + `2 TYPE description`            |
| `m: [spouse]`         | `0 @F_x@ FAM` with `HUSB`/`WIFE`/`MARR`    |
| `m: plain text`       | Single-parent FAM + `1 NOTE Spouse: ...`   |
| `div:`                | `1 DIV` under FAM                          |
| `> [child]`           | `1 CHIL @I_id@` under FAM                  |
| `> [child] (adopted)` | `CHIL` + `PEDI ADOPTED` on child's `FAMC`  |
| `> plain text`        | `1 NOTE` on the FAM record                 |
| `parents: [id], [id]` | `1 FAMC @F_x@` (creates FAM if needed)     |
| `parents: plain text` | `1 NOTE` on the INDI record                |
| `maybe:`              | Not emitted                                |
| `note:`               | `1 NOTE` (with `CONT` for multi-line)      |
| `d: ?`                | `1 DEAT Y`                                 |
| `sex: ?`              | Omitted                                    |
| `source [id]`         | `0 @S_id@ SOUR` + subrecords               |
| `src:` (person-level) | `1 SOUR` + `2 NOTE`                        |
|                       |                                            |
