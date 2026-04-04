package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/drewherron/genmark/internal/gedcom"
	"github.com/drewherron/genmark/internal/ir"
	"github.com/drewherron/genmark/internal/lexer"
	"github.com/drewherron/genmark/internal/parser"
	"github.com/drewherron/genmark/internal/resolver"
	"github.com/spf13/cobra"
)

var outputFile string

var compileCmd = &cobra.Command{
	Use:   "compile <input.gmd|dir> [...]",
	Short: "Compile .gmd files (or directories of them) to GEDCOM 5.5.1",
	Args:  cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		expanded, err := expandArgs(args)
		if err != nil {
			return err
		}
		if len(expanded) == 0 {
			return fmt.Errorf("no .gmd files found")
		}

		if outputFile == "" {
			first := args[0]
			if info, err := os.Stat(first); err == nil && info.IsDir() {
				name := filepath.Base(filepath.Clean(first))
				outputFile = filepath.Join(first, name+".ged")
			} else {
				base := strings.TrimSuffix(filepath.Base(first), filepath.Ext(first))
				outputFile = filepath.Join(filepath.Dir(first), base+".ged")
			}
		}

		files, ok := parseFiles(expanded)
		if !ok {
			return fmt.Errorf("parsing failed")
		}

		res := resolver.Resolve(files)
		printDiagnostics(res.Diagnostics)
		if res.HasErrors() {
			return fmt.Errorf("resolution failed")
		}

		out := gedcom.Emit(res)
		if err := os.WriteFile(outputFile, out, 0644); err != nil {
			return fmt.Errorf("writing %s: %w", outputFile, err)
		}
		fmt.Printf("%s: %d people, %d families, %d sources\n",
			outputFile, len(res.People), len(res.Families), len(res.Sources))
		return nil
	},
}

// expandArgs replaces any directory arguments with the .gmd files
// found recursively inside them. Plain file arguments are kept as-is.
func expandArgs(args []string) ([]string, error) {
	var result []string
	for _, arg := range args {
		info, err := os.Stat(arg)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", arg, err)
		}
		if !info.IsDir() {
			result = append(result, arg)
			continue
		}
		err = filepath.Walk(arg, func(path string, fi os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if !fi.IsDir() && strings.EqualFold(filepath.Ext(path), ".gmd") {
				result = append(result, path)
			}
			return nil
		})
		if err != nil {
			return nil, fmt.Errorf("walking %s: %w", arg, err)
		}
	}
	return result, nil
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
