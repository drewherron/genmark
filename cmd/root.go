package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "genmark",
	Short: "Genmark genealogy markup compiler",
	Long:  "Genmark compiles .gmd genealogy markup files to GEDCOM 5.5.1.",
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.AddCommand(compileCmd)
	rootCmd.AddCommand(checkCmd)
	rootCmd.AddCommand(fmtCmd)
}
