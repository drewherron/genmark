package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/drewherron/genmark/internal/ir"
	"github.com/drewherron/genmark/internal/lexer"
	"github.com/drewherron/genmark/internal/parser"
	"github.com/drewherron/genmark/internal/resolver"
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

		files, ok := parseFiles(args)
		if !ok {
			return fmt.Errorf("parsing failed")
		}

		res := resolver.Resolve(files)
		printDiagnostics(res.Diagnostics)
		if res.HasErrors() {
			return fmt.Errorf("resolution failed")
		}

		fmt.Printf("resolved: %d people, %d families, %d sources\n",
			len(res.People), len(res.Families), len(res.Sources))
		fmt.Printf("GEDCOM emission not yet implemented (would write to %s)\n", outputFile)
		return nil
	},
}

// parseFiles lexes and parses each input file, printing errors.
// Returns the parsed files and true if there were no errors.
func parseFiles(paths []string) ([]*ir.File, bool) {
	var files []*ir.File
	hasErrors := false

	for _, path := range paths {
		data, err := os.ReadFile(path)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %s\n", err)
			hasErrors = true
			continue
		}
		tokens := lexer.Lex(string(data))
		f, errs := parser.Parse(path, tokens)
		if len(errs) > 0 {
			for _, e := range errs {
				fmt.Fprintf(os.Stderr, "%s\n", e)
			}
			hasErrors = true
		}
		files = append(files, f)
	}

	return files, !hasErrors
}

func printDiagnostics(diags []resolver.Diagnostic) {
	for _, d := range diags {
		fmt.Fprintf(os.Stderr, "%s\n", d)
	}
}

func init() {
	compileCmd.Flags().StringVarP(&outputFile, "output", "o", "", "output .ged file (default: input name with .ged extension)")
}
