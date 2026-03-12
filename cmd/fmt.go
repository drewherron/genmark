package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var fmtCmd = &cobra.Command{
	Use:   "fmt <input.gmd>",
	Short: "Format a .gmd file in place",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Printf("fmt: %s (not yet implemented)\n", args[0])
		return nil
	},
}
