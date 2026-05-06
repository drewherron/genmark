// Package parser consumes a token stream from the lexer and builds
// the intermediate representation. Forward references are stored
// unresolved; resolution happens in a separate pass.
package parser

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/drewherron/genmark/internal/ir"
	"github.com/drewherron/genmark/internal/lexer"
)

// ParseError is a located error from parsing.
type ParseError struct {
	File    string
	Line    int
	Message string
}

func (e ParseError) Error() string {
	if e.File != "" {
		return fmt.Sprintf("%s:%d: %s", e.File, e.Line, e.Message)
	}
	return fmt.Sprintf("line %d: %s", e.Line, e.Message)
}

// Parse builds an ir.File from a token stream.
func Parse(filename string, tokens []lexer.Token) (*ir.File, []ParseError) {
	p := &parser{
		tokens: tokens,
		file:   &ir.File{Filename: filename},
		fname:  filename,
	}
	p.parse()
	return p.file, p.errors
}

type parser struct {
	tokens []lexer.Token
	pos    int
	file   *ir.File
	fname  string
	errors []ParseError

	person  *ir.Person
	source  *ir.Source
	union   *ir.Union
	marriage *ir.Marriage
	mIndent  int // indent of current m: line

	inNote     bool
	noteIndent int
	noteLines  []string
	noteLine   int
}

func (p *parser) errorf(line int, format string, args ...any) {
	p.errors = append(p.errors, ParseError{
		File: p.fname, Line: line, Message: fmt.Sprintf(format, args...),
	})
}

func (p *parser) next() *lexer.Token {
	if p.pos < len(p.tokens) {
		t := &p.tokens[p.pos]
		p.pos++
		return t
	}
	return nil
}

func (p *parser) finishNote() {
	if p.inNote && p.person != nil {
		p.person.Notes = append(p.person.Notes, ir.Note{
			Text: strings.Join(p.noteLines, "\n"),
			Line: p.noteLine,
		})
	}
	p.inNote = false
	p.noteLines = nil
}

func (p *parser) finishContext() {
	p.finishNote()
	if p.person != nil {
		p.file.People = append(p.file.People, *p.person)
		p.person = nil
	}
	if p.source != nil {
		p.file.Sources = append(p.file.Sources, *p.source)
		p.source = nil
	}
	if p.union != nil {
		p.file.Unions = append(p.file.Unions, *p.union)
		p.union = nil
	}
	p.marriage = nil
}

// --- main loop ---

var (
	rePersonHeader = regexp.MustCompile(`^(.+?)\s+\[(\w+)\]\s*$`)
	reSourceHeader = regexp.MustCompile(`^source\s+\[(\w+)\]\s*$`)
	reUnionHeader  = regexp.MustCompile(`^\[(\w+)\]\s*\+\s*\[(\w+)\]\s*$`)
)

func (p *parser) parse() {
	for {
		tok := p.next()
		if tok == nil {
			break
		}

		// Multi-line note continuation
		if p.inNote {
			if tok.Indent > p.noteIndent {
				p.noteLines = append(p.noteLines, tok.Text)
				continue
			}
			p.finishNote()
		}

		if tok.Indent == 0 {
			p.topLevel(tok)
		} else if p.person != nil {
			p.personField(tok)
		} else if p.source != nil {
			p.sourceField(tok)
		} else if p.union != nil {
			p.unionField(tok)
		} else {
			p.errorf(tok.Line, "unexpected indented line outside of block")
		}
	}
	p.finishContext()
}

func (p *parser) topLevel(tok *lexer.Token) {
	if m := reSourceHeader.FindStringSubmatch(tok.Text); m != nil {
		p.finishContext()
		p.source = &ir.Source{ID: m[1], Line: tok.Line}
		return
	}
	if m := reUnionHeader.FindStringSubmatch(tok.Text); m != nil {
		p.finishContext()
		p.union = &ir.Union{SpouseIDs: []string{m[1], m[2]}, Line: tok.Line}
		return
	}
	if m := rePersonHeader.FindStringSubmatch(tok.Text); m != nil {
		p.finishContext()
		p.person = &ir.Person{
			DisplayName: strings.TrimSpace(m[1]),
			ID:          m[2],
			Line:        tok.Line,
		}
		return
	}
	p.errorf(tok.Line, "unrecognized top-level line: %s", tok.Text)
}

// --- person fields ---

func (p *parser) personField(tok *lexer.Token) {
	if strings.HasPrefix(tok.Text, ">") {
		p.childRef(tok)
		return
	}

	// Non-child field at or below the marriage indent ends the marriage context
	if p.marriage != nil && tok.Indent <= p.mIndent {
		p.marriage = nil
	}

	tag, val, ok := splitField(tok.Text)
	if !ok {
		p.errorf(tok.Line, "expected field (tag: value), got: %s", tok.Text)
		return
	}

	switch tag {
	case "aka":
		p.person.Aliases = append(p.person.Aliases, val)
	case "sex":
		p.person.Sex = strings.TrimSpace(val)
	case "b", "d", "chr", "bur", "imm", "res", "bap", "nat", "emi", "crm", "cen", "mil", "occ", "evt":
		p.person.Events = append(p.person.Events, p.parseEvent(tag, val, tok.Line))
	case "m":
		m := p.parseMarriage(val, tok.Line)
		p.person.Marriages = append(p.person.Marriages, m)
		p.marriage = &p.person.Marriages[len(p.person.Marriages)-1]
		p.mIndent = tok.Indent
	case "div":
		p.person.Divorces = append(p.person.Divorces, p.parseDivorce(val, tok.Line))
	case "parents":
		p.person.Parents = append(p.person.Parents, parseParents(val, tok.Line))
	case "maybe":
		p.person.MaybeLinks = append(p.person.MaybeLinks, parseMaybe(val, tok.Line))
	case "note":
		if strings.TrimSpace(val) == "|" {
			p.inNote = true
			p.noteIndent = tok.Indent
			p.noteLines = nil
			p.noteLine = tok.Line
		} else {
			p.person.Notes = append(p.person.Notes, ir.Note{Text: val, Line: tok.Line})
		}
	case "src":
		p.person.Sources = append(p.person.Sources, ir.PersonSource{Value: val, Line: tok.Line})
	default:
		p.errorf(tok.Line, "unknown person field: %s", tag)
	}
}

func (p *parser) childRef(tok *lexer.Token) {
	ref := parseChildRefValue(tok.Text, tok.Line)
	if p.marriage != nil {
		p.marriage.Children = append(p.marriage.Children, ref)
	} else if p.union != nil {
		p.union.Children = append(p.union.Children, ref)
	} else {
		p.errorf(tok.Line, "child reference outside of marriage or union")
	}
}

// --- source fields ---

func (p *parser) sourceField(tok *lexer.Token) {
	tag, val, ok := splitField(tok.Text)
	if !ok {
		p.errorf(tok.Line, "expected field (tag: value), got: %s", tok.Text)
		return
	}
	switch tag {
	case "title":
		p.source.Title = val
	case "author":
		p.source.Author = val
	case "pub":
		p.source.Pub = val
	case "url":
		p.source.URL = val
	case "repo":
		p.source.Repo = val
	case "page":
		p.source.Page = val
	case "note":
		p.source.Note = val
	default:
		p.errorf(tok.Line, "unknown source field: %s", tag)
	}
}

// --- union fields ---

func (p *parser) unionField(tok *lexer.Token) {
	if strings.HasPrefix(tok.Text, ">") {
		ref := parseChildRefValue(tok.Text, tok.Line)
		if p.marriage != nil && tok.Indent > p.mIndent {
			p.marriage.Children = append(p.marriage.Children, ref)
		} else {
			p.union.Children = append(p.union.Children, ref)
		}
		return
	}

	if p.marriage != nil && tok.Indent <= p.mIndent {
		p.marriage = nil
	}

	tag, val, ok := splitField(tok.Text)
	if !ok {
		p.errorf(tok.Line, "expected field (tag: value), got: %s", tok.Text)
		return
	}
	if tag == "m" {
		m := p.parseUnionMarriage(val, tok.Line)
		p.union.Marriage = &m
		p.marriage = p.union.Marriage
		p.mIndent = tok.Indent
	} else {
		p.errorf(tok.Line, "unknown union field: %s", tag)
	}
}

// --- field parsing helpers ---

func splitField(text string) (tag, value string, ok bool) {
	idx := strings.Index(text, ":")
	if idx < 0 {
		return "", "", false
	}
	return strings.TrimSpace(text[:idx]), strings.TrimSpace(text[idx+1:]), true
}

func parseChildRefValue(text string, line int) ir.ChildRef {
	text = strings.TrimSpace(strings.TrimPrefix(strings.TrimPrefix(text, ">"), " "))
	ref := ir.ChildRef{Line: line}

	// Check for modifier in trailing parentheses — only strip if recognized
	if pStart := strings.LastIndex(text, "("); pStart >= 0 {
		if pEnd := strings.LastIndex(text, ")"); pEnd > pStart {
			if mod, ok := tryChildModifier(text[pStart+1 : pEnd]); ok {
				ref.Modifier = mod
				text = strings.TrimSpace(text[:pStart])
			}
		}
	}

	if strings.Contains(text, "[") {
		ref.ID = extractFirstID(text)
	} else {
		ref.PlainText = strings.TrimSpace(text)
	}
	return ref
}

// parseEvent handles every event field with the unified grammar:
//
//	[description] [(date) | bare-date] [@ place]
//
// Parens are required when both description and date appear on the same
// line; with a bare leading date (and no description), parens are
// optional. All three components are optional; what makes sense
// depends on the field.
func (p *parser) parseEvent(tag, val string, line int) ir.Event {
	evt := ir.Event{Tag: tag, Line: line}
	val, evt.Sources = extractSourceCitations(val)

	left, place := splitOnAt(val)
	evt.Place = place

	if pStart := strings.Index(left, "("); pStart >= 0 {
		// Description-with-parenthesized-date form.
		if pEnd := strings.Index(left[pStart:], ")"); pEnd >= 0 {
			dateStr := strings.TrimSpace(left[pStart+1 : pStart+pEnd])
			before := strings.TrimRight(left[:pStart], " ")
			after := left[pStart+pEnd+1:]
			evt.Desc = strings.TrimSpace(before + after)
			if dateStr != "" {
				evt.Date = p.parseDate(line, dateStr)
			}
		} else {
			evt.Desc = strings.TrimSpace(left)
		}
	} else if left != "" {
		if looksLikeDate(left) {
			evt.Date = p.parseDate(line, left)
		} else {
			evt.Desc = left
		}
	}

	// For occupations, a range date represents the period held.
	if tag == "occ" && evt.Date.Modifier == ir.ModRange {
		evt.Period = &ir.DateRange{From: evt.Date.From, To: evt.Date.To}
		evt.Date = ir.Date{}
	}
	return evt
}

func (p *parser) parseMarriage(val string, line int) ir.Marriage {
	m := ir.Marriage{Line: line}
	val, m.Sources = extractSourceCitations(val)

	// Extract spouse ID from leading [id]
	if start := strings.Index(val, "["); start >= 0 {
		if end := strings.Index(val[start:], "]"); end >= 0 {
			m.SpouseID = val[start+1 : start+end]
			val = strings.TrimSpace(val[start+end+1:])
			m.Date, m.Place = p.parseDatePlace(line, val)
			return m
		}
	}

	// No [id]: either a date-first marriage (no recorded spouse) or
	// a plain-text spouse name. Split off the place first, then look
	// at the left side.
	left, place := splitOnAt(val)
	m.Place = place

	if left == "" || looksLikeDate(left) {
		if left != "" {
			m.Date = p.parseDate(line, left)
		}
		return m
	}

	// Plain-text spouse, with an optional date in parentheses.
	desc, date := p.extractDescDate(line, left)
	m.PlainText = desc
	m.Date = date
	return m
}

func (p *parser) parseUnionMarriage(val string, line int) ir.Marriage {
	m := ir.Marriage{Line: line}
	val, m.Sources = extractSourceCitations(val)
	m.Date, m.Place = p.parseDatePlace(line, val)
	return m
}

func (p *parser) parseDivorce(val string, line int) ir.Divorce {
	d := ir.Divorce{Line: line}
	val, d.Sources = extractSourceCitations(val)

	if start := strings.Index(val, "["); start >= 0 {
		if end := strings.Index(val[start:], "]"); end >= 0 {
			d.SpouseID = val[start+1 : start+end]
			val = strings.TrimSpace(val[start+end+1:])
		}
	}

	d.Date, d.Place = p.parseDatePlace(line, val)
	return d
}

func parseParents(val string, line int) ir.ParentRef {
	ref := ir.ParentRef{Line: line}

	// Check for modifier — only strip if it's a recognized modifier
	if pIdx := strings.LastIndex(val, "("); pIdx >= 0 {
		if pEnd := strings.LastIndex(val, ")"); pEnd > pIdx {
			if mod, ok := tryChildModifier(val[pIdx+1 : pEnd]); ok {
				ref.Modifier = mod
				val = strings.TrimSpace(val[:pIdx])
			}
		}
	}

	if strings.Contains(val, "[") {
		ref.IDs = extractAllIDs(val)
	} else {
		ref.PlainText = strings.TrimSpace(val)
	}
	return ref
}

func parseMaybe(val string, line int) ir.MaybeLink {
	ml := ir.MaybeLink{Line: line}
	if idx := strings.Index(val, "["); idx >= 0 {
		ml.Relation = strings.TrimSpace(val[:idx])
		ml.IDs = extractAllIDs(val)
	} else {
		ml.Relation = strings.TrimSpace(val)
	}
	return ml
}

// --- date / place / source parsing ---

func (p *parser) parseDatePlace(line int, s string) (ir.Date, string) {
	s = strings.TrimSpace(s)
	if s == "" {
		return ir.Date{}, ""
	}
	dateStr, place := splitOnAt(s)
	var d ir.Date
	if dateStr != "" {
		d = p.parseDate(line, dateStr)
	}
	return d, place
}

// extractDescDate splits "Description (date)" into description and date.
// Used by description-first fields (occ, mil, evt).
// Handles trailing text: "US Army (1945..1947), MP" → "US Army, MP"
func (p *parser) extractDescDate(line int, s string) (string, ir.Date) {
	s = strings.TrimSpace(s)
	if pStart := strings.Index(s, "("); pStart >= 0 {
		if pEnd := strings.Index(s[pStart:], ")"); pEnd >= 0 {
			dateStr := strings.TrimSpace(s[pStart+1 : pStart+pEnd])
			before := strings.TrimRight(s[:pStart], " ")
			after := s[pStart+pEnd+1:]
			return strings.TrimSpace(before + after), p.parseDate(line, dateStr)
		}
	}
	return s, ir.Date{}
}

func splitOnAt(s string) (left, right string) {
	s = strings.TrimSpace(s)
	if idx := strings.Index(s, "@"); idx >= 0 {
		return strings.TrimSpace(s[:idx]), strings.TrimSpace(s[idx+1:])
	}
	return s, ""
}

// looksLikeDate reports whether s starts with something the date parser
// would accept: a 4-digit year (optionally preceded by ~ < >) or a bare ?.
// Used to disambiguate date-first marriage lines from plain-text spouse
// names.
func looksLikeDate(s string) bool {
	s = strings.TrimSpace(s)
	if s == "" {
		return false
	}
	if s == "?" {
		return true
	}
	if s[0] == '~' || s[0] == '<' || s[0] == '>' {
		s = s[1:]
	}
	if len(s) < 4 {
		return false
	}
	for i := 0; i < 4; i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

func (p *parser) parseDate(line int, s string) ir.Date {
	s = strings.TrimSpace(s)
	if s == "" {
		return ir.Date{}
	}
	if s == "?" {
		return ir.Date{Modifier: ir.ModUnknown}
	}
	// Strip an outer pair of parens. This lets `(date)` work as a
	// synonym for a bare date in places where no description is present
	// (e.g. `m: [id] (1721-10-20) @ ...`), parallel to the optional
	// parens around dates in the unified event grammar.
	if len(s) >= 2 && s[0] == '(' && s[len(s)-1] == ')' {
		if inner := strings.TrimSpace(s[1 : len(s)-1]); inner != "" {
			return p.parseDate(line, inner)
		}
	}
	if parts := strings.SplitN(s, "..", 2); len(parts) == 2 {
		from := strings.TrimSpace(parts[0])
		to := strings.TrimSpace(parts[1])
		// Open-ended ranges aren't allowed: GEDCOM 5.5.1 expresses
		// "before/after a date" with BEF/AFT, not an open BET..AND.
		switch {
		case from == "" || to == "" || from == "?" || to == "?":
			// Open-ended ranges aren't allowed: GEDCOM 5.5.1 expresses
			// "before/after a date" with BEF/AFT, not an open BET..AND.
			p.errorf(line, "open-ended date range %q is not allowed; use <YYYY (before) or >YYYY (after) instead", s)
		case hasDateModifier(from) || hasDateModifier(to):
			// GEDCOM 5.5.1 BET <DATE> AND <DATE> takes plain dates;
			// ABT/CAL/EST cannot appear inside a range. A range
			// already conveys imprecision.
			p.errorf(line, "modifiers (~ < >) are not allowed on range endpoints in %q; a range already implies imprecision -- write %s..%s", s, stripDateModifier(from), stripDateModifier(to))
		case !looksLikeDate(from) || !looksLikeDate(to):
			p.errorf(line, "invalid date range %q: each endpoint must be a year (e.g., 1888..1895)", s)
		}
		return ir.Date{Modifier: ir.ModRange, From: from, To: to}
	}
	if !looksLikeDate(s) {
		p.errorf(line, "invalid date %q: expected a year like 1888 or 1888-05-15. Prefix a place with @ (e.g., \"@ Boston, Massachusetts\")", s)
	}
	if strings.HasPrefix(s, "~") {
		return ir.Date{Modifier: ir.ModAbout, From: strings.TrimSpace(s[1:])}
	}
	if strings.HasPrefix(s, "<") {
		return ir.Date{Modifier: ir.ModBefore, From: strings.TrimSpace(s[1:])}
	}
	if strings.HasPrefix(s, ">") {
		return ir.Date{Modifier: ir.ModAfter, From: strings.TrimSpace(s[1:])}
	}
	return ir.Date{Modifier: ir.ModNone, From: s}
}

func hasDateModifier(s string) bool {
	if s == "" {
		return false
	}
	c := s[0]
	return c == '~' || c == '<' || c == '>'
}

func stripDateModifier(s string) string {
	if hasDateModifier(s) {
		return strings.TrimSpace(s[1:])
	}
	return s
}

func extractSourceCitations(val string) (string, []ir.SourceCitation) {
	var cites []ir.SourceCitation
	for {
		srcIdx := strings.LastIndex(val, "[src:")
		if srcIdx < 0 {
			break
		}
		endIdx := strings.Index(val[srcIdx:], "]")
		if endIdx < 0 {
			break
		}
		endIdx += srcIdx

		content := strings.TrimSpace(val[srcIdx+5 : endIdx])
		c := ir.SourceCitation{}
		if commaIdx := strings.Index(content, ","); commaIdx >= 0 {
			left := strings.TrimSpace(content[:commaIdx])
			if !strings.Contains(left, " ") {
				// Looks like an ID reference: [src: id, detail]
				c.ID = left
				c.Detail = strings.TrimSpace(content[commaIdx+1:])
			} else {
				// Free-form text with comma: [src: Some Book, p. 14]
				c.Text = content
			}
		} else if !strings.Contains(content, " ") {
			c.ID = content
		} else {
			c.Text = content
		}
		cites = append(cites, c)
		val = strings.TrimSpace(val[:srcIdx])
	}
	// Reverse to source order
	for i, j := 0, len(cites)-1; i < j; i, j = i+1, j-1 {
		cites[i], cites[j] = cites[j], cites[i]
	}
	return val, cites
}

// --- helpers ---

func extractFirstID(text string) string {
	start := strings.Index(text, "[")
	end := strings.Index(text, "]")
	if start >= 0 && end > start {
		return text[start+1 : end]
	}
	return ""
}

func extractAllIDs(text string) []string {
	var ids []string
	rest := text
	for {
		start := strings.Index(rest, "[")
		end := strings.Index(rest, "]")
		if start < 0 || end <= start {
			break
		}
		ids = append(ids, rest[start+1:end])
		rest = rest[end+1:]
	}
	return ids
}

func tryChildModifier(s string) (ir.ChildModifier, bool) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "adopted":
		return ir.ChildAdopted, true
	case "step":
		return ir.ChildStep, true
	case "foster":
		return ir.ChildFoster, true
	case "stillborn":
		return ir.ChildStillborn, true
	case "died young":
		return ir.ChildDiedYoung, true
	default:
		return ir.ChildBio, false
	}
}

