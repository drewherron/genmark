// Package lexer tokenizes .gmd source files into a stream of tokens.
// Each token carries its line number, indent depth, and text content.
// Comments (// and /* */) are stripped. Blank lines are discarded.
package lexer

import "strings"

// Token represents a meaningful line in a .gmd source file.
type Token struct {
	Line   int    // 1-based line number in source
	Indent int    // number of leading spaces
	Text   string // content with leading whitespace stripped
}

// Lex processes .gmd source text, stripping comments and blank lines.
func Lex(source string) []Token {
	var tokens []Token
	lines := strings.Split(source, "\n")
	inBlock := false

	for i, line := range lines {
		num := i + 1

		if inBlock {
			if idx := strings.Index(line, "*/"); idx >= 0 {
				inBlock = false
				line = line[idx+2:]
			} else {
				continue
			}
		}

		// Strip block comments (may be multiple on one line)
		for {
			bcIdx := findMarker(line, "/*")
			if bcIdx < 0 {
				break
			}
			rest := line[bcIdx+2:]
			line = line[:bcIdx]
			if endIdx := strings.Index(rest, "*/"); endIdx >= 0 {
				line += rest[endIdx+2:]
			} else {
				inBlock = true
				break
			}
		}

		// Strip single-line comment
		if cIdx := findMarker(line, "//"); cIdx >= 0 {
			line = line[:cIdx]
		}

		if t := makeToken(line, num); t != nil {
			tokens = append(tokens, *t)
		}
	}

	return tokens
}

func makeToken(line string, num int) *Token {
	if strings.TrimSpace(line) == "" {
		return nil
	}
	indent := 0
	for _, ch := range line {
		if ch == ' ' {
			indent++
		} else if ch == '\t' {
			indent += 2
		} else {
			break
		}
	}
	return &Token{Line: num, Indent: indent, Text: strings.TrimSpace(line)}
}

// findMarker finds a comment marker (// or /*) that is either at the
// start of the line or preceded by whitespace. This prevents treating
// :// in URLs as a comment.
func findMarker(line, marker string) int {
	for i := 0; i <= len(line)-len(marker); i++ {
		if line[i:i+len(marker)] == marker {
			if i == 0 || line[i-1] == ' ' || line[i-1] == '\t' {
				return i
			}
		}
	}
	return -1
}
