package cmd

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var outputFile string

var compileCmd = &cobra.Command{
	Use:   "compile <input.gmd>",
	Short: "Compile a .gmd file to GEDCOM 5.5.1",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		input := args[0]
		if outputFile == "" {
			base := strings.TrimSuffix(filepath.Base(input), filepath.Ext(input))
			outputFile = filepath.Join(filepath.Dir(input), base+".ged")
		}
		fmt.Printf("compile: %s -> %s (not yet implemented)\n", input, outputFile)
		return nil
	},
}

func init() {
	compileCmd.Flags().StringVarP(&outputFile, "output", "o", "", "output .ged file (default: input name with .ged extension)")
}
