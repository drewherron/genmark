# Genmark Syntax Reference

Genmark is a plain-text language for writing genealogical data. It
compiles to GEDCOM 5.5.1, the standard interchange format for
genealogy software.

Genmark files use the `.gmd` extension. This document describes the
correct syntax of a `.gmd` file. The intent is that the Genmark
language stands on its own and no knowledge of GEDCOM is necessary to
use it. There is some information in this guide about how Genmark
actually maps to GEDCOM, but you can safely ignore that if you want
to.

---

## File Structure

A `.gmd` file contains three kinds of top-level blocks, in any order:

- **Person records** (`Full Name [id]`)
- **Source definitions** (`source [id]`)
- **Standalone unions** (`[id] + [id]`)

A block starts at its header line (column 0, no indentation) and
includes everything indented below it. Blank lines within indented
content are part of the block; a blank line followed by unindented
content ends it.  Unindented comments directly above a header (with no
blank line between) are also considered part of that block. Unindented
comments separated from any block by blank lines are standalone --
useful as section markers in longer files.

Multiple `.gmd` files can be compiled together into a single GEDCOM
output.  References between files are resolved automatically. This
allows you to organize your genealogical data however you want.

---

## Person Records

A person record starts (at column 0, no indentation) with a display
name, then a unique ID in square brackets. Any fields for that person
are placed on indented lines following that initial line.

```
Jane Elizabeth Doe [jane_doe]
  sex: F
  b: 1892-08-12 @ Boston, Massachusetts
  d: 1965-11-03 @ Queens, New York
```

Not all fields are required. Even a record with no fields at all is
valid and useful as a stub - for example, a spouse you only know by
name:

```
John Doe [john_doe]
```

---

## Name Handling

You can wrap the surname in slashes on the header line so the compiler
knows exactly which part of the name is the surname:

```
John Arthur /Doe/ [john]                       -->  John Arthur /Doe/
Maria del /García López/ [maria]               -->  Maria del /García López/
Johannes /van der Berg/ [johannes]             -->  Johannes /van der Berg/
```

This is recommended for any name that isn't a simple Western
`First [Middle] Last`, including multi-word surnames, particles
(`van der`, `de la`), hyphenated surnames, and surname-first naming
orders.

If slashes are omitted, the compiler falls back to a heuristic: the
last word is treated as the surname, with recognized suffixes (`Jr.`,
`Sr.`, `I`–`V`, `Esq.`) placed after it.

```
John Arthur Doe [john]     -->  John Arthur /Doe/
John Doe Sr. [john_sr]     -->  John /Doe/ Sr.
```

The heuristic works well for the simple case but will mangle the
others. When in doubt, use slashes.

---

## Person Fields

`d: ?` is a special form that means "known to be deceased, no
details," compiling to `1 DEAT Y`. It's the only place a bare `?` is
accepted — for any other unknown value, omit the field entirely.

Three fields can appear only once per person: `sex`, `b`, `d`. The
rest are allowed to appear multiple times (although it may not make
much sense in some cases).

### Identity Fields

```
aka: Alternate Name
```

Multiple `aka:` lines are allowed. Each produces an additional GEDCOM NAME tag.

```
sex: M / F
```

If sex is unknown, omit the field — GEDCOM allows an absent SEX.

### Life Events

All event fields share a single grammar:

```
tag: [description] [(date) | bare-date] [@ place]
```

Every component is optional; what makes sense depends on the field
(birth dates rarely need a description, generic events rarely omit
one). Two rules cover all cases:

- `@` marks the place. It's required whenever a place is present.
- When a description and a date appear on the same line, the date goes
  in parentheses. With no description, parens around the date are
  optional.

```
b: 1888 @ London                          // bare date + place
b: 1888                                   // date only
b: @ London                               // place only
b: Premature (1888-03-15) @ London        // description + date + place
b: (1888) @ London                        // parens optional with no description

bur: Unmarked grave @ Mount Wollaston Cemetery, Quincy
occ: Carpenter (1910..1920) @ London
mil: US Army, Military Police (1945..1947)
evt: Graduated (1942-06) @ Columbia University
```

**Putting a cemetery, church, or other sub-place inside a place.** The
parser splits the line on the *first* `@`. Everything to the right is
the place string, taken as-is. To record a cemetery (or church,
hospital, etc.) inside a town, comma-separate them inside the place
string — do **not** add a second `@`:

```
bur: 1965-11-05 @ Maple Cemetery, Winthrop, Maine     // correct
bur: @ Maple Cemetery, Winthrop, Maine                // correct (no date)
bur: Unmarked grave @ Maple Cemetery, Winthrop, ME    // correct (description + place)
```

| Tag    | Meaning        | GEDCOM Tag |
|--------|----------------|------------|
| `b:`   | Birth          | `BIRT`     |
| `d:`   | Death          | `DEAT`     |
| `chr:` | Christening    | `CHR`      |
| `bap:` | Baptism        | `BAPM`     |
| `bur:` | Burial         | `BURI`     |
| `crm:` | Cremation      | `CREM`     |
| `imm:` | Immigration    | `IMMI`     |
| `emi:` | Emigration     | `EMIG`     |
| `nat:` | Naturalization | `NATU`     |
| `res:` | Residence      | `RESI`     |
| `cen:` | Census         | `CENS`     |
| `occ:` | Occupation     | `OCCU`     |
| `mil:` | Military       | `EVEN`     |
| `evt:` | Generic event  | `EVEN`     |

A description on a standard event tag (e.g., `bur: Unmarked grave @
...`) compiles to `2 TYPE <description>` under the event — the
GEDCOM-conformant way to qualify a standard event ("stillborn" on
`BIRT`, "Common Law" on `MARR`, etc.).

For most fields, the description qualifies the event — `b: Premature
(1888)` means the birth was premature; `bur: Unmarked grave @ ...`
means the burial was in an unmarked grave. Two fields use the
description slot a little differently:

- **`mil:`** is the dedicated military-service field. The event is
  always classified as military service in the output; the description
  is for the user's specifics (unit, role, branch). Use this whenever
  you're recording any kind of military service.

  ```
  mil: US Army, Military Police (1945..1947)
  mil: Royal Navy, HMS Belfast @ Portsmouth
  ```

- **`evt:`** is the catch-all for events that don't have a dedicated
  tag. The description names what kind of event it was — it carries
  the classification.

  ```
  evt: Earned PhD (1962) @ Yale University
  evt: Survived Galveston hurricane (1900-09)
  ```

  If you find yourself using `evt:` repeatedly for the same kind of
  event (e.g., baptisms), check whether there's already a dedicated
  tag for it in the table above.

---

## Relationships

### Marriage

```
m: [spouse_id] date @ place
  > [child_id]
  > [child_id] (adopted)
```

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

### Speculative Items (`maybe:`)

```
maybe: brother [id]
maybe: father [id]
maybe: parents [id], [id]
maybe: res Seattle around 1920
```

`maybe:` records something you suspect but haven't confirmed — most
often a relationship, but any text is allowed. These lines are **not
emitted to GEDCOM**.

`genmark check` lists every `maybe:` entry with its file and line
number, giving you a running list of unverified facts. When the target
is written as `[id]`, the reference is validated against your defined
records — typos like `[edard_doe]` surface as warnings.

### Research Reminders (`todo:`)

```
todo: Find baptism record at St. Mark's
todo: Verify 1850 census entry
```

`todo:` records a research task — something you intend to look into.
Like `maybe:`, todos are **not emitted to GEDCOM**. Run `genmark todo`
to print every `todo:` entry across your files with location info, so
you can pick up where you left off.

### `maybe:` vs `todo:` vs `note:` vs `// comment`

All four can hold freeform text on a person, but they differ in intent
and in what tooling does with them:

| Field         | Mental model                                    | Emits to GEDCOM? | Surfaced by                  |
| ------------- | ----------------------------------------------- | ---------------- | ---------------------------- |
| `maybe:`      | "I think this is true but haven't confirmed"    | No               | `genmark check`              |
| `todo:`       | "I should look into this"                       | No               | `genmark todo`               |
| `note:`       | Prose you want preserved on the record          | Yes (as `NOTE`)  | Anyone reading the GEDCOM    |
| `// comment`  | Aside for yourself in the source file           | No               | Nothing — never parsed       |

Reach for `maybe:` and `todo:` when you want the compiler to track the
item for you and (in `maybe:`'s case) validate any `[id]` references.
Reach for `note:` when the information belongs in the published
record. Reach for `// comments` for asides that shouldn't appear
anywhere.

---

## Plain-Text References

Square brackets create a link to a defined record. When you omit the
brackets, the text is treated as a plain name with **no record
linkage**.  No new person record is created — but the name is never
dropped. It attaches as a note to whichever existing record it most
naturally belongs to.

This is useful at the edges of the tree — people you know by name but
don't intend to track as full records.

| Where you write it                | What's preserved                          | Attached to                          |
| --------------------------------- | ----------------------------------------- | ------------------------------------ |
| `parents: Edward Smith, Mary ...` | The parents' names                        | The current person                   |
| `m: Jane Doe ...`                 | The spouse's name (plus date/place if any)| A new family record for the marriage |
| `> Robert Doe` (under `m:`)       | The child's name                          | The family record for that marriage  |
| `maybe: cousin John Doe`          | The full speculative note                 | Nothing — kept for your reference    |

In every case the name survives in the output; the only thing that
changes is which record it rides along with. You don't need to think
about the GEDCOM structure to use these — write the name where it
naturally belongs and the compiler handles placement.

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

### Speculative Items

```
maybe: brother [id]
maybe: cousin John Doe
```

Since `maybe:` items are not emitted to GEDCOM, plain text works
naturally here — the text is simply stored for the researcher's
reference. See the [Speculative Items](#speculative-items-maybe)
section above for full details.

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
```

If a date is unknown, omit it. The one exception is `d: ?`, which is a
deliberate marker meaning "known to be deceased, no details" (see the
Identity Fields section above).

Modifiers `~`, `<`, `>` combine with partial dates: `~1888-05` means
"approximately May 1888."

**Modifiers do not combine with ranges.** A range already implies
uncertainty, and GEDCOM 5.5.1 forbids approximation modifiers inside
`BET <DATE> AND <DATE>` (DATE_RANGE takes plain dates only). All of
these are rejected at compile time:

```
~1843..1846      // wrong -- modifier on whole range
1843..~1846      // wrong -- modifier on an endpoint
~1843..~1846     // wrong -- modifier on both endpoints
```

Write the plain range instead: `1843..1846`. If you only know one
endpoint, use `<` or `>` rather than an open-ended range:

```
1957..      // wrong -- open-ended range
~1961..     // wrong -- open-ended range
~1980..?    // wrong -- ? is not a valid endpoint
?..2008     // wrong -- ? is not a valid endpoint

>1957       // correct -- "after 1957"
<2008       // correct -- "before 2008"
```

These rules apply to every date in a `.gmd` file. A range currently
compiles to GEDCOM `BET <DATE> AND <DATE>` on every field, so it
expresses uncertainty about *when* the event happened — "born sometime
between 1888 and 1890." For duration-natural fields like `occ:`,
`mil:`, and `res:`, this is often not what you'd want to convey
("Carpenter 1910..1920" usually means "held the job throughout that
span," not "started the job sometime in that window"). Emitting to
FROM on those fields is planned for the next Genmark version.
 
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

**Potential Workflow**: dump a link now with bare `src:`, attach it to
a fact later with inline `[src:]`, and promote it to a full defined
source when multiple people reference it.

---

## Comments

Both comment forms are **completely ignored** by the compiler. They
never appear in GEDCOM output.

```
// Single-line comment

/* Block comment.
   Can span multiple lines.
   Use for raw source material: obituaries, census
   transcriptions, research notes. */
```

Comments are for the human reader of the Genmark file only. Use
`note:` for text that should compile to GEDCOM.

**Recommended approach for rich biographical data:**

1. Structured facts go in proper fields (`b:`, `res:`, `mil:`, `occ:`, etc.)
2. Biographical context that belongs in the record goes in `note:` (compiles to GEDCOM NOTE)
3. Raw source material (full obituary text, census transcriptions) goes in `/* block comments */` (ignored by compiler)

### Comments and Blocks in Editors

Comments directly above a record header (with no blank line between),
and everything indented below it (regardless of blank lines), are
considered part of that block for folding and movement in the Emacs
mode. Unindented comments separated from records by blank lines are
standalone -- they stay visible when blocks are folded and can be used
as section markers. See [editor/EDITORS.md](editor/EDITORS.md) for
details.

Currently this block definition only applies to Emacs, but it's good
to follow this standardized convention (knowing when blank lines and
indents define a block). This behavior will be expanded to other
editors in the future when/where possible.

### URLs in Comments

Comment markers `//` and `/*` are only recognized when preceded by
whitespace or at the start of a line. This prevents `://` in URLs from
being treated as a comment:

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

Everything indented beneath the `|` belongs to the note. Blank lines
within are preserved. The block ends when indentation returns to the
enclosing level.

---

## IDs

IDs appear in square brackets: `[john_doe]`, `[src_1920_census]`.

- On a header line, brackets define the ID. Everywhere else, they reference it.
- Forward references are valid: you can reference `[jane]` in a marriage line before Jane's record appears in the file.
- Must be unique across *all* compiled files.
- User-chosen short handles, not auto-generated. Convention encourages contextual IDs like `[john_chicago]` or `[grandpa_john]` or `[john_doe_1920]` over `[john_doe_1]`, but that's entirely up to the user.
- An undefined reference is an error at compile time (except in `maybe:` lines, which produce warnings).

---

## Family Merging

Families can be declared from multiple directions, and the compiler
merges them into a single GEDCOM FAM record:

1. **Top-down**: `m: [spouse]` with `> [child]` lines on a person record
2. **Bottom-up**: `parents: [id], [id]` on a child's record
3. **Standalone**: `[id] + [id]` union block

All three can coexist. If both spouses declare the same marriage, or a
child's `parents:` line matches an existing couple, the compiler
unifies them. If details conflict (different dates or places), the
compiler warns.

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
| description (on standard event) | `2 TYPE description`             |
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
| `maybe:`              | Not emitted (listed by `genmark check`)    |
| `todo:`               | Not emitted (listed by `genmark todo`)     |
| `note:`               | `1 NOTE` (with `CONT` for multi-line)      |
| `d: ?`                | `1 DEAT Y`                                 |
| `source [id]`         | `0 @S_id@ SOUR` + subrecords               |
| `src:` (person-level) | `1 SOUR` + `2 NOTE`                        |
|                       |                                            |
