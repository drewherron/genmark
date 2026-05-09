package cmd

import (
	"fmt"

	"github.com/drewherron/genmark/internal/ir"
	"github.com/spf13/cobra"
)

var todoCmd = &cobra.Command{
	Use:   "todo <input.gmd|dir> [...]",
	Short: "List todo: research reminders across .gmd files",
	Args:  cobra.MinimumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		expanded, err := expandArgs(args)
		if err != nil {
			return err
		}
		if len(expanded) == 0 {
			return fmt.Errorf("no .gmd files found")
		}
		files, ok := parseFiles(expanded)
		if !ok {
			return fmt.Errorf("todo failed with parse errors")
		}
		printTodos(files)
		return nil
	},
}

// printTodos lists every `todo:` entry across the parsed files.
func printTodos(files []*ir.File) {
	type entry struct {
		file, name, text string
		line             int
	}
	var entries []entry
	for _, f := range files {
		for i := range f.People {
			p := &f.People[i]
			for _, t := range p.Todos {
				entries = append(entries, entry{f.Filename, p.DisplayName, t.Text, t.Line})
			}
		}
	}
	if len(entries) == 0 {
		fmt.Println("No todos.")
		return
	}
	fmt.Printf("%d todo(s):\n", len(entries))
	for _, e := range entries {
		fmt.Printf("  %s:%d  %s — %s\n", e.file, e.line, e.name, e.text)
	}
}
