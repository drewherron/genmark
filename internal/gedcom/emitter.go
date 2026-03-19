// Package gedcom walks the resolved IR and emits valid GEDCOM 5.5.1.
package gedcom

import (
	"bytes"
	"fmt"
	"strconv"
	"strings"

	"github.com/drewherron/genmark/internal/ir"
	"github.com/drewherron/genmark/internal/resolver"
)

// Emit produces a GEDCOM 5.5.1 byte stream from a resolved result.
func Emit(res *resolver.Result) []byte {
	e := &emitter{
		res:        res,
		famIDs:     make(map[*resolver.Family]string),
		spouseFams: make(map[string][]*resolver.Family),
		childFams:  make(map[string][]childEntry),
	}
	return e.emit()
}

type childEntry struct {
	family   *resolver.Family
	modifier ir.ChildModifier
}

type emitter struct {
	res        *resolver.Result
	buf        bytes.Buffer
	famIDs     map[*resolver.Family]string
	spouseFams map[string][]*resolver.Family
	childFams  map[string][]childEntry
}

func (e *emitter) emit() []byte {
	e.assignFamilyIDs()
	e.buildLookups()
	e.header()
	for _, s := range e.res.Sources {
		e.emitSource(s)
	}
	for _, p := range e.res.People {
		e.emitPerson(p)
	}
	for _, f := range e.res.Families {
		e.emitFamily(f)
	}
	e.tag(0, "TRLR")
	return e.buf.Bytes()
}

func (e *emitter) assignFamilyIDs() {
	for i, f := range e.res.Families {
		e.famIDs[f] = fmt.Sprintf("F%d", i+1)
	}
}

func (e *emitter) buildLookups() {
	for _, f := range e.res.Families {
		if f.HusbandID != "" {
			e.spouseFams[f.HusbandID] = append(e.spouseFams[f.HusbandID], f)
		}
		if f.WifeID != "" {
			e.spouseFams[f.WifeID] = append(e.spouseFams[f.WifeID], f)
		}
		for _, childID := range f.Children {
			mod := ir.ChildBio
			if m, ok := f.ChildMods[childID]; ok {
				mod = m
			}
			e.childFams[childID] = append(e.childFams[childID], childEntry{
				family:   f,
				modifier: mod,
			})
		}
	}
}

// --- output helpers ---

func (e *emitter) record(level int, xref, tag string) {
	fmt.Fprintf(&e.buf, "%d @%s@ %s\n", level, xref, tag)
}

func (e *emitter) tag(level int, tag string, value ...string) {
	if len(value) > 0 && value[0] != "" {
		fmt.Fprintf(&e.buf, "%d %s %s\n", level, tag, value[0])
	} else {
		fmt.Fprintf(&e.buf, "%d %s\n", level, tag)
	}
}

func (e *emitter) ref(level int, tag, xref string) {
	fmt.Fprintf(&e.buf, "%d %s @%s@\n", level, tag, xref)
}

// --- header / source / person / family ---

func (e *emitter) header() {
	e.tag(0, "HEAD")
	e.tag(1, "SOUR", "GENMARK")
	e.tag(2, "VERS", "0.1")
	e.tag(2, "NAME", "Genmark")
	e.tag(1, "GEDC")
	e.tag(2, "VERS", "5.5.1")
	e.tag(2, "FORM", "LINEAGE-LINKED")
	e.tag(1, "CHAR", "UTF-8")
}

func (e *emitter) emitSource(s *ir.Source) {
	e.record(0, sourRef(s.ID), "SOUR")
	if s.Title != "" {
		e.tag(1, "TITL", s.Title)
	}
	if s.Author != "" {
		e.tag(1, "AUTH", s.Author)
	}
	if s.Pub != "" {
		e.tag(1, "PUBL", s.Pub)
	}
	if s.Repo != "" {
		e.tag(1, "REPO")
		e.tag(2, "NAME", s.Repo)
	}
	if s.URL != "" {
		e.tag(1, "NOTE", s.URL)
	}
	if s.Note != "" {
		e.emitNote(1, s.Note)
	}
}

func (e *emitter) emitPerson(p *ir.Person) {
	e.record(0, indiRef(p.ID), "INDI")

	// Primary name
	e.tag(1, "NAME", formatName(p.DisplayName))

	// Aliases
	for _, aka := range p.Aliases {
		e.tag(1, "NAME", aka)
	}

	// Sex (omit if unknown)
	if p.Sex == "M" || p.Sex == "F" {
		e.tag(1, "SEX", p.Sex)
	}

	// Events
	for _, evt := range p.Events {
		e.emitEvent(evt)
	}

	// FAMS pointers
	for _, fam := range e.spouseFams[p.ID] {
		e.ref(1, "FAMS", e.famIDs[fam])
	}

	// FAMC pointers
	for _, ce := range e.childFams[p.ID] {
		e.ref(1, "FAMC", e.famIDs[ce.family])
		switch ce.modifier {
		case ir.ChildAdopted:
			e.tag(2, "PEDI", "ADOPTED")
		case ir.ChildStep:
			e.tag(2, "PEDI", "STEP")
		case ir.ChildFoster:
			e.tag(2, "PEDI", "FOSTER")
		}
	}

	// Plain-text parents as NOTE
	for _, pr := range p.Parents {
		if pr.PlainText != "" {
			e.tag(1, "NOTE", "Parents: "+pr.PlainText)
		}
	}

	// Notes
	for _, n := range p.Notes {
		e.emitNote(1, n.Text)
	}

	// Person-level sources
	for _, s := range p.Sources {
		e.tag(1, "SOUR")
		e.tag(2, "NOTE", s.Value)
	}
}

func (e *emitter) emitEvent(evt ir.Event) {
	// d: ? → DEAT Y
	if evt.Tag == "d" && evt.Date.Modifier == ir.ModUnknown {
		e.tag(1, "DEAT", "Y")
		return
	}

	switch evt.Tag {
	case "mil":
		e.tag(1, "EVEN")
		e.tag(2, "TYPE", "Military Service")
		if evt.Desc != "" {
			e.tag(2, "NOTE", evt.Desc)
		}
		if evt.Place != "" {
			e.tag(2, "PLAC", evt.Place)
		}
		e.emitSourceCitations(2, evt.Sources)

	case "evt":
		e.tag(1, "EVEN")
		if evt.Desc != "" {
			e.tag(2, "TYPE", evt.Desc)
		}
		if dateStr := formatDate(evt.Date); dateStr != "" {
			e.tag(2, "DATE", dateStr)
		}
		if evt.Place != "" {
			e.tag(2, "PLAC", evt.Place)
		}
		e.emitSourceCitations(2, evt.Sources)

	case "occ":
		if evt.Desc != "" {
			e.tag(1, "OCCU", evt.Desc)
		} else {
			e.tag(1, "OCCU")
		}
		if evt.Period != nil {
			e.tag(2, "DATE", "BET "+isoToGedcom(evt.Period.From)+" AND "+isoToGedcom(evt.Period.To))
		}
		if evt.Place != "" {
			e.tag(2, "PLAC", evt.Place)
		}
		e.emitSourceCitations(2, evt.Sources)

	default:
		gedTag := eventTagMap[evt.Tag]
		if gedTag == "" {
			gedTag = strings.ToUpper(evt.Tag)
		}
		dateStr := formatDate(evt.Date)
		e.tag(1, gedTag)
		if dateStr != "" {
			e.tag(2, "DATE", dateStr)
		}
		if evt.Place != "" {
			e.tag(2, "PLAC", evt.Place)
		}
		e.emitSourceCitations(2, evt.Sources)
	}
}

func (e *emitter) emitFamily(fam *resolver.Family) {
	e.record(0, e.famIDs[fam], "FAM")

	if fam.HusbandID != "" {
		e.ref(1, "HUSB", indiRef(fam.HusbandID))
	}
	if fam.WifeID != "" {
		e.ref(1, "WIFE", indiRef(fam.WifeID))
	}

	// Marriage event
	hasMarr := fam.Date.From != "" || fam.Date.Modifier != ir.ModNone ||
		fam.Place != "" || len(fam.Sources) > 0
	if hasMarr {
		e.tag(1, "MARR")
		if dateStr := formatDate(fam.Date); dateStr != "" {
			e.tag(2, "DATE", dateStr)
		}
		if fam.Place != "" {
			e.tag(2, "PLAC", fam.Place)
		}
		e.emitSourceCitations(2, fam.Sources)
	}

	// Divorce
	if fam.Divorced {
		divDate := formatDate(fam.DivDate)
		if divDate != "" || fam.DivPlace != "" {
			e.tag(1, "DIV")
			if divDate != "" {
				e.tag(2, "DATE", divDate)
			}
			if fam.DivPlace != "" {
				e.tag(2, "PLAC", fam.DivPlace)
			}
		} else {
			e.tag(1, "DIV", "Y")
		}
	}

	// Children
	for _, childID := range fam.Children {
		e.ref(1, "CHIL", indiRef(childID))
	}
}

// --- source citations ---

func (e *emitter) emitSourceCitations(level int, cites []ir.SourceCitation) {
	for _, c := range cites {
		if c.ID != "" {
			e.ref(level, "SOUR", sourRef(c.ID))
			if c.Detail != "" {
				e.tag(level+1, "PAGE", c.Detail)
			}
		} else if c.Text != "" {
			e.tag(level, "SOUR")
			e.tag(level+1, "TEXT", c.Text)
		}
	}
}

// --- notes ---

func (e *emitter) emitNote(level int, text string) {
	lines := strings.Split(text, "\n")
	e.tag(level, "NOTE", lines[0])
	for _, l := range lines[1:] {
		e.tag(level+1, "CONT", l)
	}
}

// --- name formatting ---

// formatName converts "William Arthur Herron" to "William Arthur /Herron/".
func formatName(displayName string) string {
	parts := strings.Fields(displayName)
	if len(parts) == 0 {
		return ""
	}
	if len(parts) == 1 {
		return "/" + parts[0] + "/"
	}
	surname := parts[len(parts)-1]
	given := strings.Join(parts[:len(parts)-1], " ")
	return given + " /" + surname + "/"
}

// --- date formatting ---

var monthNames = [13]string{
	"", "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
}

// formatDate converts an ir.Date to a GEDCOM date string.
func formatDate(d ir.Date) string {
	if d.Modifier == ir.ModUnknown {
		return ""
	}
	from := isoToGedcom(d.From)
	if from == "" && d.Modifier != ir.ModRange {
		return ""
	}
	switch d.Modifier {
	case ir.ModAbout:
		return "ABT " + from
	case ir.ModBefore:
		return "BEF " + from
	case ir.ModAfter:
		return "AFT " + from
	case ir.ModRange:
		to := isoToGedcom(d.To)
		return "BET " + from + " AND " + to
	default:
		return from
	}
}

// isoToGedcom converts "1888-05-15" → "15 MAY 1888", "1888-05" → "MAY 1888", "1888" → "1888".
func isoToGedcom(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	parts := strings.Split(s, "-")
	switch len(parts) {
	case 3:
		month, _ := strconv.Atoi(parts[1])
		day, _ := strconv.Atoi(parts[2])
		if month >= 1 && month <= 12 {
			return fmt.Sprintf("%d %s %s", day, monthNames[month], parts[0])
		}
	case 2:
		month, _ := strconv.Atoi(parts[1])
		if month >= 1 && month <= 12 {
			return fmt.Sprintf("%s %s", monthNames[month], parts[0])
		}
	}
	return s
}

// --- reference helpers ---

func indiRef(personID string) string { return "I_" + personID }
func sourRef(sourceID string) string { return "S_" + sourceID }

var eventTagMap = map[string]string{
	"b":   "BIRT",
	"d":   "DEAT",
	"chr": "CHR",
	"bur": "BURI",
	"imm": "IMMI",
	"res": "RESI",
}
