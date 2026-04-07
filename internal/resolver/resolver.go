// Package resolver performs the second pass over parsed IR: resolving
// references, merging family records, and producing diagnostics.
package resolver

import (
	"fmt"
	"sort"

	"github.com/drewherron/genmark/internal/ir"
)

// Severity classifies a diagnostic message.
type Severity int

const (
	Warning Severity = iota
	Error
)

// Diagnostic is a located message from resolution.
type Diagnostic struct {
	File     string
	Line     int
	Message  string
	Severity Severity
}

func (d Diagnostic) String() string {
	sev := "warning"
	if d.Severity == Error {
		sev = "error"
	}
	if d.File != "" {
		return fmt.Sprintf("%s:%d: %s: %s", d.File, d.Line, sev, d.Message)
	}
	return fmt.Sprintf("line %d: %s: %s", d.Line, sev, d.Message)
}

// Family is a resolved family group with GEDCOM-ready role assignments.
type Family struct {
	HusbandID string // person ID assigned to HUSB (may be empty)
	WifeID    string // person ID assigned to WIFE (may be empty)
	Date      ir.Date
	Place     string
	Sources   []ir.SourceCitation
	Children      []string                    // ordered, deduplicated child IDs
	ChildMods     map[string]ir.ChildModifier // only set for non-biological
	PlainChildren []PlainChild                // unlinked children (no record)
	PlainSpouse   string                      // plain-text spouse name (no record)
	Divorced      bool
	DivDate   ir.Date
	DivPlace  string
}

// PlainChild is an unlinked child name at the edge of the tree.
type PlainChild struct {
	Name     string
	Modifier ir.ChildModifier
}

// Result is the output of the resolver.
type Result struct {
	People      []*ir.Person
	PersonIndex map[string]*ir.Person
	Families    []*Family
	Sources     []*ir.Source
	SourceIndex map[string]*ir.Source
	Diagnostics []Diagnostic
}

// HasErrors returns true if any diagnostic is an error.
func (r *Result) HasErrors() bool {
	for _, d := range r.Diagnostics {
		if d.Severity == Error {
			return true
		}
	}
	return false
}

// Resolve takes parsed files and produces a resolved result with
// merged families and validated references.
func Resolve(files []*ir.File) *Result {
	r := &resolver{
		personIndex: make(map[string]*ir.Person),
		sourceIndex: make(map[string]*ir.Source),
		familyIndex: make(map[string]*Family),
		personFile:  make(map[string]string),
	}
	r.resolve(files)
	return r.result()
}

type resolver struct {
	people      []*ir.Person
	personIndex map[string]*ir.Person
	personFile  map[string]string // person ID → filename

	sources     []*ir.Source
	sourceIndex map[string]*ir.Source

	families    []*Family
	familyIndex map[string]*Family // couple key → family

	diagnostics []Diagnostic
}

func (r *resolver) diag(file string, line int, sev Severity, format string, args ...any) {
	r.diagnostics = append(r.diagnostics, Diagnostic{
		File: file, Line: line, Severity: sev,
		Message: fmt.Sprintf(format, args...),
	})
}

func (r *resolver) resolve(files []*ir.File) {
	for _, f := range files {
		r.indexFile(f)
	}
	for _, f := range files {
		r.buildFamilies(f)
	}
	for _, f := range files {
		r.validateRefs(f)
	}
}

func (r *resolver) result() *Result {
	sort.Slice(r.diagnostics, func(i, j int) bool {
		di, dj := r.diagnostics[i], r.diagnostics[j]
		if di.File != dj.File {
			return di.File < dj.File
		}
		return di.Line < dj.Line
	})
	return &Result{
		People:      r.people,
		PersonIndex: r.personIndex,
		Families:    r.families,
		Sources:     r.sources,
		SourceIndex: r.sourceIndex,
		Diagnostics: r.diagnostics,
	}
}

// --- indexing ---

func (r *resolver) indexFile(f *ir.File) {
	for i := range f.People {
		p := &f.People[i]
		if existing, ok := r.personIndex[p.ID]; ok {
			r.diag(f.Filename, p.Line, Error,
				"duplicate person ID %q (first defined at %s:%d)",
				p.ID, r.personFile[p.ID], existing.Line)
			continue
		}
		r.personIndex[p.ID] = p
		r.personFile[p.ID] = f.Filename
		r.people = append(r.people, p)
	}

	for i := range f.Sources {
		s := &f.Sources[i]
		if existing, ok := r.sourceIndex[s.ID]; ok {
			r.diag(f.Filename, s.Line, Error,
				"duplicate source ID %q (first defined at line %d)",
				s.ID, existing.Line)
			continue
		}
		r.sourceIndex[s.ID] = s
		r.sources = append(r.sources, s)
	}
}

// --- family building ---

// coupleKey produces a canonical key for a pair of spouse IDs.
func coupleKey(id1, id2 string) string {
	if id1 > id2 {
		id1, id2 = id2, id1
	}
	return id1 + "\x00" + id2
}

func (r *resolver) getOrCreateFamily(id1, id2 string) *Family {
	key := coupleKey(id1, id2)
	if f, ok := r.familyIndex[key]; ok {
		return f
	}
	f := &Family{
		ChildMods: make(map[string]ir.ChildModifier),
	}
	r.assignRoles(f, id1, id2)
	r.familyIndex[key] = f
	r.families = append(r.families, f)
	return f
}

// createSingleParentFamily builds a fresh Family record for a marriage
// where one spouse is named only as plain text. The known person is
// assigned HUSB or WIFE based on their sex (defaulting to HUSB when
// unknown), and the plain-text name is stored for emission as a NOTE
// on the FAM. These families are intentionally not added to familyIndex
// since they have no second ID to merge against.
func (r *resolver) createSingleParentFamily(soloID, plainSpouse string) *Family {
	f := &Family{
		ChildMods:   make(map[string]ir.ChildModifier),
		PlainSpouse: plainSpouse,
	}
	if r.getSex(soloID) == "F" {
		f.WifeID = soloID
	} else {
		f.HusbandID = soloID
	}
	r.families = append(r.families, f)
	return f
}

func (r *resolver) assignRoles(f *Family, id1, id2 string) {
	sex1, sex2 := r.getSex(id1), r.getSex(id2)

	switch {
	case sex1 == "M" && sex2 == "F":
		f.HusbandID, f.WifeID = id1, id2
	case sex1 == "F" && sex2 == "M":
		f.HusbandID, f.WifeID = id2, id1
	case sex1 == "M":
		f.HusbandID, f.WifeID = id1, id2
	case sex2 == "M":
		f.HusbandID, f.WifeID = id2, id1
	case sex1 == "F":
		f.HusbandID, f.WifeID = id2, id1
	case sex2 == "F":
		f.HusbandID, f.WifeID = id1, id2
	default:
		f.HusbandID, f.WifeID = id1, id2
	}
}

func (r *resolver) getSex(id string) string {
	if p, ok := r.personIndex[id]; ok {
		return p.Sex
	}
	return ""
}

func (r *resolver) buildFamilies(f *ir.File) {
	for i := range f.People {
		p := &f.People[i]

		for _, m := range p.Marriages {
			var fam *Family
			switch {
			case m.SpouseID != "":
				fam = r.getOrCreateFamily(p.ID, m.SpouseID)
			case m.PlainText != "":
				fam = r.createSingleParentFamily(p.ID, m.PlainText)
			default:
				continue
			}
			r.mergeMarriageInfo(fam, m, f.Filename)
			for _, c := range m.Children {
				r.addChild(fam, c)
			}
		}

		for _, d := range p.Divorces {
			if d.SpouseID == "" {
				continue
			}
			fam := r.getOrCreateFamily(p.ID, d.SpouseID)
			fam.Divorced = true
			if d.Date.From != "" || d.Date.Modifier != ir.ModNone {
				fam.DivDate = d.Date
			}
			if d.Place != "" {
				fam.DivPlace = d.Place
			}
		}

		for _, pr := range p.Parents {
			if pr.PlainText != "" {
				continue // plain-text parents don't create families
			}
			if len(pr.IDs) == 0 {
				continue
			}
			var fam *Family
			if len(pr.IDs) >= 2 {
				fam = r.getOrCreateFamily(pr.IDs[0], pr.IDs[1])
			} else {
				fam = r.getOrCreateFamily(pr.IDs[0], "")
			}
			r.addChild(fam, ir.ChildRef{
				ID:       p.ID,
				Modifier: pr.Modifier,
				Line:     pr.Line,
			})
		}
	}

	for i := range f.Unions {
		u := &f.Unions[i]
		if len(u.SpouseIDs) != 2 {
			continue
		}
		fam := r.getOrCreateFamily(u.SpouseIDs[0], u.SpouseIDs[1])
		if u.Marriage != nil {
			r.mergeMarriageInfo(fam, *u.Marriage, f.Filename)
			for _, c := range u.Marriage.Children {
				r.addChild(fam, c)
			}
		}
		for _, c := range u.Children {
			r.addChild(fam, c)
		}
	}
}

func (r *resolver) mergeMarriageInfo(fam *Family, m ir.Marriage, filename string) {
	hasDate := m.Date.From != "" || m.Date.Modifier != ir.ModNone
	if hasDate {
		famHasDate := fam.Date.From != "" || fam.Date.Modifier != ir.ModNone
		if famHasDate && fam.Date.From != m.Date.From {
			r.diag(filename, m.Line, Warning,
				"conflicting marriage date: %q vs existing %q",
				m.Date.From, fam.Date.From)
		}
		if !famHasDate {
			fam.Date = m.Date
		}
	}

	if m.Place != "" {
		if fam.Place != "" && fam.Place != m.Place {
			r.diag(filename, m.Line, Warning,
				"conflicting marriage place: %q vs existing %q",
				m.Place, fam.Place)
		}
		if fam.Place == "" {
			fam.Place = m.Place
		}
	}

	fam.Sources = append(fam.Sources, m.Sources...)
}

func (r *resolver) addChild(fam *Family, ref ir.ChildRef) {
	if ref.PlainText != "" {
		fam.PlainChildren = append(fam.PlainChildren, PlainChild{
			Name:     ref.PlainText,
			Modifier: ref.Modifier,
		})
		return
	}
	for _, id := range fam.Children {
		if id == ref.ID {
			return
		}
	}
	fam.Children = append(fam.Children, ref.ID)
	if ref.Modifier != ir.ChildBio {
		fam.ChildMods[ref.ID] = ref.Modifier
	}
}

// --- reference validation ---

func (r *resolver) validateRefs(f *ir.File) {
	for _, p := range f.People {
		for _, m := range p.Marriages {
			if m.SpouseID != "" {
				r.checkPersonRef(f.Filename, m.Line, m.SpouseID, "marriage spouse")
			}
			for _, c := range m.Children {
				if c.PlainText == "" {
					r.checkPersonRef(f.Filename, c.Line, c.ID, "child")
				}
			}
			r.checkSourceCites(f.Filename, m.Line, m.Sources)
		}

		for _, d := range p.Divorces {
			if d.SpouseID != "" {
				r.checkPersonRef(f.Filename, d.Line, d.SpouseID, "divorce spouse")
			}
			r.checkSourceCites(f.Filename, d.Line, d.Sources)
		}

		for _, pr := range p.Parents {
			for _, id := range pr.IDs {
				r.checkPersonRef(f.Filename, pr.Line, id, "parent")
			}
		}

		for _, ml := range p.MaybeLinks {
			for _, id := range ml.IDs {
				if _, ok := r.personIndex[id]; !ok {
					r.diag(f.Filename, ml.Line, Warning,
						"maybe reference to undefined person %q", id)
				}
			}
		}

		for _, e := range p.Events {
			r.checkSourceCites(f.Filename, e.Line, e.Sources)
		}
	}

	for _, u := range f.Unions {
		for _, id := range u.SpouseIDs {
			r.checkPersonRef(f.Filename, u.Line, id, "union spouse")
		}
	}
}

func (r *resolver) checkPersonRef(file string, line int, id, context string) {
	if _, ok := r.personIndex[id]; !ok {
		r.diag(file, line, Error, "undefined person %q in %s", id, context)
	}
}

func (r *resolver) checkSourceCites(file string, line int, cites []ir.SourceCitation) {
	for _, c := range cites {
		if c.ID != "" {
			if _, ok := r.sourceIndex[c.ID]; !ok {
				r.diag(file, line, Warning,
					"source citation references undefined source %q", c.ID)
			}
		}
	}
}
