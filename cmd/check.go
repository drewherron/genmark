package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var checkCmd = &cobra.Command{
	Use:   "check <input.gmd>",
	Short: "Validate a .gmd file without compiling",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Printf("check: %s (not yet implemented)\n", args[0])
		return nil
	},
}
