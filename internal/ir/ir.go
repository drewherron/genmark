// Package ir defines the intermediate representation produced by the
// parser and consumed by the resolver and GEDCOM emitter.
package ir

// DateModifier qualifies a date expression.
type DateModifier int

const (
	ModNone   DateModifier = iota // exact or partial date
	ModAbout                      // ~1888
	ModBefore                     // <1888
	ModAfter                      // >1888
	ModRange                      // 1888..1895
	ModUnknown                    // ?
)

// Date represents a parsed date expression. For ranges, From holds
// the start and To holds the end. For unknown dates, Modifier is
// ModUnknown and both strings are empty.
type Date struct {
	Modifier DateModifier
	From     string // YYYY, YYYY-MM, or YYYY-MM-DD
	To       string // only set for ModRange
}

// SourceCitation is an inline [src: ...] reference on a fact line.
// If ID is non-empty, it refers to a defined Source by ID.
// If ID is empty, Text holds the raw inline citation string.
type SourceCitation struct {
	ID     string // matches a Source.ID, if predefined
	Detail string // optional detail after the comma: [src: id, p. 42]
	Text   string // raw text for one-off citations: [src: Boston Records, p.3]
	Line   int
}

// Event represents a dated, located fact (birth, death, residence, etc.).
type Event struct {
	Tag     string // b, d, chr, bur, imm, res, mil, occ, evt, div
	Date    Date
	Place   string
	Desc    string          // for evt: and mil: free-form prefix; for occ: the occupation name
	Period  *DateRange      // for occ/res contextual ranges: (1910..1920)
	Sources []SourceCitation
	Line    int
}

// DateRange is a contextual period used on occ and res lines.
type DateRange struct {
	From string
	To   string
}

// ChildRef is a child listed under a marriage or union block.
type ChildModifier int

const (
	ChildBio       ChildModifier = iota
	ChildAdopted
	ChildStep
	ChildFoster
	ChildStillborn
	ChildDiedYoung
)

type ChildRef struct {
	ID       string
	Modifier ChildModifier
	Line     int
}

// Marriage holds everything declared on an m: line and its children.
type Marriage struct {
	SpouseID string
	Date     Date
	Place    string
	Sources  []SourceCitation
	Children []ChildRef
	Line     int
}

// Divorce holds a div: line.
type Divorce struct {
	SpouseID string
	Date     Date
	Place    string
	Sources  []SourceCitation
	Line     int
}

// ParentRef is a parents: declaration on a person, pointing up to
// two parents and carrying an optional relationship modifier.
// If PlainText is set, the parents are not linked records.
type ParentRef struct {
	IDs       []string // one or two parent IDs (when using [id] references)
	PlainText string   // raw text for unlinked parents at tree edges
	Modifier  ChildModifier
	Line      int
}

// MaybeLink is a speculative relationship (maybe: brother [id]).
type MaybeLink struct {
	Relation string // "brother", "father", "parents", etc.
	IDs      []string
	Line     int
}

// Note is either a single-line or multi-line note: block.
type Note struct {
	Text string // newlines preserved for multi-line notes
	Line int
}

// PersonSource is a bare src: line attached to a person as a whole,
// not to any specific event.
type PersonSource struct {
	Value string // URL, citation string, or source ID
	Line  int
}

// Person is the central record type.
type Person struct {
	ID          string
	DisplayName string
	Aliases     []string      // aka: lines
	Sex         string        // "M", "F", "?"
	Events      []Event       // all life events in source order
	Marriages   []Marriage    // m: blocks
	Divorces    []Divorce     // div: lines
	Parents     []ParentRef   // parents: lines
	MaybeLinks  []MaybeLink   // maybe: lines
	Notes       []Note        // note: lines
	Sources     []PersonSource // bare src: lines
	Line        int
}

// Union is a standalone [id] + [id] block.
type Union struct {
	SpouseIDs []string // exactly two
	Marriage  *Marriage
	Children  []ChildRef
	Line      int
}

// Source is a defined source block.
type Source struct {
	ID     string
	Title  string
	Author string
	Pub    string
	URL    string
	Repo   string
	Page   string
	Note   string
	Line   int
}

// File is the top-level result of parsing a .gmd file.
type File struct {
	Filename string
	Sources  []Source
	People   []Person
	Unions   []Union
}
