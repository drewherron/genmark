package cmd

import (
	"fmt"

	"github.com/drewherron/genmark/internal/resolver"
	"github.com/spf13/cobra"
)

var checkCmd = &cobra.Command{
	Use:   "check <input.gmd> [input2.gmd ...]",
	Short: "Validate one or more .gmd files without compiling",
	Args:  cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		files, ok := parseFiles(args)
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
