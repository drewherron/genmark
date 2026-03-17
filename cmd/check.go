package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var checkCmd = &cobra.Command{
	Use:   "check <input.gmd> [input2.gmd ...]",
	Short: "Validate one or more .gmd files without compiling",
	Args:  cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		files, ok := parseFiles(args)
		if !ok {
			return fmt.Errorf("check failed with errors")
		}

		total := 0
		for _, f := range files {
			total += len(f.People)
			fmt.Printf("%s: %d people, %d sources, %d unions\n",
				f.Filename, len(f.People), len(f.Sources), len(f.Unions))
		}
		fmt.Printf("OK: %d file(s), %d total people\n", len(files), total)
		return nil
	},
}
