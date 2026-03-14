package cmd

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var outputFile string

var compileCmd = &cobra.Command{
	Use:   "compile <input.gmd> [input2.gmd ...]",
	Short: "Compile one or more .gmd files to GEDCOM 5.5.1",
	Args:  cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		if outputFile == "" {
			base := strings.TrimSuffix(filepath.Base(args[0]), filepath.Ext(args[0]))
			outputFile = filepath.Join(filepath.Dir(args[0]), base+".ged")
		}
		fmt.Printf("compile: %v -> %s (not yet implemented)\n", args, outputFile)
		return nil
	},
}

func init() {
	compileCmd.Flags().StringVarP(&outputFile, "output", "o", "", "output .ged file (default: input name with .ged extension)")
}
