package cmd

import (
	"fmt"
	"strings"

	"github.com/drewherron/genmark/internal/ir"
	"github.com/drewherron/genmark/internal/resolver"
	"github.com/spf13/cobra"
)

var checkCmd = &cobra.Command{
	Use:   "check <input.gmd|dir> [...]",
	Short: "Validate .gmd files (or directories of them) without compiling",
	Args:  cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		expanded, err := expandArgs(args)
		if err != nil {
			return err
		}
		if len(expanded) == 0 {
			return fmt.Errorf("no .gmd files found")
		}
		files, ok := parseFiles(expanded)
		if !ok {
			return fmt.Errorf("check failed with parse errors")
		}

		res := resolver.Resolve(files)
		printDiagnostics(res.Diagnostics)

		errors, warnings := 0, 0
		for _, d := range res.Diagnostics {
			if d.Severity == resolver.Error {
				errors++
			} else {
				warnings++
			}
		}

		fmt.Printf("%d people, %d families, %d sources\n",
			len(res.People), len(res.Families), len(res.Sources))
		printSpeculativeLinks(files)
		if errors > 0 {
			return fmt.Errorf("check failed: %d error(s), %d warning(s)", errors, warnings)
		}
		if warnings > 0 {
			fmt.Printf("OK with %d warning(s)\n", warnings)
		} else {
			fmt.Println("OK")
		}
		return nil
	},
}

// printSpeculativeLinks lists every `maybe:` entry across the parsed files
// so the user has a research to-do list. These never reach GEDCOM.
func printSpeculativeLinks(files []*ir.File) {
	type entry struct {
		file, name, body string
		line             int
	}
	var entries []entry
	for _, f := range files {
		for i := range f.People {
			p := &f.People[i]
			for _, ml := range p.MaybeLinks {
				body := ml.Relation
				if len(ml.IDs) > 0 {
					refs := make([]string, len(ml.IDs))
					for i, id := range ml.IDs {
						refs[i] = "[" + id + "]"
					}
					body = strings.TrimSpace(body + " " + strings.Join(refs, ", "))
				}
				entries = append(entries, entry{f.Filename, p.DisplayName, body, ml.Line})
			}
		}
	}
	if len(entries) == 0 {
		return
	}
	fmt.Printf("%d speculative link(s):\n", len(entries))
	for _, e := range entries {
		fmt.Printf("  %s:%d  %s — %s\n", e.file, e.line, e.name, e.body)
	}
}
