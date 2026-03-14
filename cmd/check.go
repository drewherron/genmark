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
		fmt.Printf("check: %v (not yet implemented)\n", args)
		return nil
	},
}
