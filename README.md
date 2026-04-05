# Genmark

Genmark is a plain-text language for writing genealogical data. It compiles to
[GEDCOM 5.5.1](https://www.familysearch.org/developers/docs/gedcom/), the
standard interchange format used by genealogy software.

Genmark files use the `.gmd` extension.

## Why?

GEDCOM is the universal format for sharing family trees between software, but it
was designed for machines, not people. A single person with a birth date and
place looks like this:

```
0 @I_mary_smith@ INDI
1 NAME Mary Ellen /Smith/
1 SEX F
1 BIRT
2 DATE MAR 1895
2 PLAC Portland, Oregon
1 DEAT
2 DATE 28 FEB 1978
2 PLAC Portland, Oregon
1 FAMS @F1@
```

In Genmark, the same person would be:

```
Mary Ellen Smith [mary_smith]
  sex: F
  b: 1895-03 @ Portland, Oregon
  d: 1978-02-28 @ Portland, Oregon
```

The idea is that a Genmark file can be the actual repository of your research
data, not just an import/export format for some application. When you come
across a new source, or person, or information about a person, just add it
directly to the file in the appropriate place. Because it's plain text, your
data works with any editor, plays well with version control, and is easy to
diff/grep/etc - but unlike other plain-text formats, it's also easy to read.

Genmark can also compile multiple `.gmd` files into a single GEDCOM
file. References to people and sources are resolved across all files. This means
you can organize your genealogical data however you want. You could keep a
separate file per individual person, or break it up by branch of the family
tree, or by state, or country, or generation, etc. For situations where you have
a large amount of material to organize, you could even devote a separate
subdirectory to each person, filling it with images and documents related to
them, including a `.gmd` file. Genmark can compile recursively through
subdirectories.

## Installation

### Download

Pre-built binaries are available on the
[Releases](https://github.com/drewherron/genmark/releases) page for Linux,
macOS (Intel and Apple Silicon), and Windows. Download the appropriate file,
make it executable if necessary, and place it somewhere on your PATH:

```
# Linux
chmod +x genmark-linux-amd64
sudo mv genmark-linux-amd64 /usr/local/bin/genmark

# macOS
chmod +x genmark-darwin-arm64
sudo mv genmark-darwin-arm64 /usr/local/bin/genmark

# Windows: rename genmark-windows-amd64.exe to genmark.exe
# and place it in a directory on your PATH
```

### Build from source

Requires [Go](https://go.dev/dl/) 1.25 or later.

```
go install github.com/drewherron/genmark@latest
```

Or clone and build:

```
git clone https://github.com/drewherron/genmark.git
cd genmark
go build -o genmark .
```

## Usage

### Compile

Compile one or more `.gmd` files to GEDCOM:

```
genmark compile family.gmd
```

This produces `family.ged` in the same directory. To specify the output file:

```
genmark compile family.gmd -o output.ged
```

Multiple files can be compiled together. References between files are resolved
automatically:

```
genmark compile parents.gmd children.gmd -o tree.ged
```

You can compile all `.gmd` files in the current directory with a shell glob:

```
genmark compile *.gmd -o tree.ged
```

Or pass a directory to recursively compile every `.gmd` file in it:

```
genmark compile ./family/ -o tree.ged
```

### Check

Validate files without producing output:

```
genmark check family.gmd
```

Reports errors (undefined references, conflicting data) and warnings
(speculative links, unused sources) with line numbers and filenames.

## Quick Example

```
source [src_census]
  title: 1920 United States Federal Census
  repo: National Archives, Washington, D.C.

Mary Ellen Smith [mary_smith]
  sex: F
  b: 1895-03 @ Portland, Oregon
  d: 1978-02-28 @ Portland, Oregon
  m: [john_doe] 1915-06-20 @ Portland, Oregon
    > [robert_doe]
    > [alice_doe]
    > William Doe
  note: Obituary lists eight grandchildren.

John Arthur Doe [john_doe]
  sex: M
  b: 1892-08-12 @ Boston, Massachusetts  [src: src_census, p. 14]
  occ: Carpenter (1910..1920) @ Brooklyn, New York
  d: 1965-11-03 @ Portland, Oregon

Robert Doe [robert_doe]
  sex: M

Alice Doe [alice_doe]
  sex: F
```

A single example using most available fields:

```
// Here's a comment!
John Arthur Doe Sr. [john_doe]
  aka: Jack Doe
  sex: M
  b: 1892-08-12 @ Boston, Suffolk, Massachusetts
  imm: 1888 @ New York, New York
  nat: 1905-03-15 @ Brooklyn, Kings, New York
  res: 1920 @ Portland, Multnomah, Oregon
  cen: 1920-01-05 @ Portland, Multnomah, Oregon  [src: src_census]
  occ: Carpenter (1910..1920) @ Brooklyn, New York
  mil: US Army (1917..1919), 26th Infantry Division
  evt: Graduated summa cum laude (1912-06) @ Columbia University, New York
  m: [mary_smith] 1915-06-20 @ Portland, Oregon
    > [robert_doe]
    > [alice_doe]
    > Catherine Doe  // Not a reference - compiled to note on current person
  div: [mary_smith] 1950
  parents: [james_doe], [elizabeth_oconnor]
  maybe: cousin Samuel Doe of Richmond
  d: 1965-11-03 @ Portland, Multnomah, Oregon
  bur: @ River View Cemetery, Portland, Oregon
  note: Known in the community as "Jack."
  src: https://www.findagrave.com/memorial/12345/john-doe
  /* Multiline block
     comments are
     also allowed */
```

See [SYNTAX.md](SYNTAX.md) for the full language reference and
[EXAMPLES.gmd](EXAMPLES.gmd) for a working file demonstrating every feature.

## Working with GEDCOM Files

The `.ged` file that Genmark produces is a standard GEDCOM file. If you're
new to GEDCOM, here are some things you can do with it:

**Import into genealogy software.** Most genealogy applications can import
GEDCOM files directly:

- [Gramps](https://gramps-project.org/) (free, open source, Linux/macOS/Windows)
- [RootsMagic](https://rootsmagic.com/)
- [Family Tree Maker](https://www.mackiev.com/ftm/)
- [Legacy Family Tree](https://legacyfamilytree.com/)

**Upload to online platforms.** Many genealogy websites accept GEDCOM
uploads to build interactive trees and connect with other researchers:

- [FamilySearch](https://www.familysearch.org/)
- [Ancestry](https://www.ancestry.com/)
- [MyHeritage](https://www.myheritage.com/)
- [WikiTree](https://www.wikitree.com/)

**Visualize your tree.** Some tools specialize in rendering GEDCOM data as
charts or diagrams:

- [Gramps](https://gramps-project.org/) has built-in tree and fan charts
- [GEDkeeper](https://gedkeeper.net/) (free, Windows/Linux)

**Share with family.** A `.ged` file is the standard way to send a family
tree to a relative who uses different software than you. Any genealogy
application should be able to open it.

## Editor Support

Syntax highlighting, folding, and indentation are available for Emacs, Vim, and
VS Code. See the [editor/](editor/) directory for installation instructions.

## License

MIT
