// cmd/dockerlings/main.go
package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"

	// Our internal packages
	"github.com/furkan/dockerlings/internal/exercises"
	"github.com/furkan/dockerlings/internal/progress"
	"github.com/furkan/dockerlings/internal/tui" // We will create this next
	"github.com/furkan/dockerlings/internal/util"

	// New imports
	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"
)

// This is the command that will be run when the user types `dockerlings check`.
var checkCmd = &cobra.Command{
	Use:   "check",
	Short: "Checks the solution for a given exercise",
	Run: func(cmd *cobra.Command, args []string) {
		projectRoot, err := util.GetProjectRoot()
		if err != nil {
			log.Fatalf("Error finding project root: %v", err)
		}

		exerciseID := "core-01"
		fmt.Printf("Checking exercise: %s...\n", exerciseID)

		// Build absolute paths instead of relative ones.
		exerciseDir := filepath.Join(projectRoot, "exercises", exerciseID)
		scriptPath := filepath.Join(exerciseDir, "check.sh")

		if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
			log.Fatalf("Error: check.sh script not found for exercise %s at %s", exerciseID, scriptPath)
		}

		command := exec.Command("/bin/bash", scriptPath)
		command.Dir = exerciseDir

		err = command.Run()
		if err != nil {
			// The command failed. Now we can print the detailed error message.
			fmt.Printf("❌ Exercise core-01 failed.\n\n")

			// You can still log the exit code for more technical detail if you want.
			if exitError, ok := err.(*exec.ExitError); ok {
				log.Printf("Script exited with code: %d\n", exitError.ExitCode())
			}
			return
		}

		fmt.Println("✅ Exercise core-01 passed!")

		p, err := progress.Load()
		if err != nil {
			log.Fatalf("Could not load progress: %v", err)
		}

		isCompleted := false
		for _, id := range p.CompletedIDs {
			if id == "core-01" {
				isCompleted = true
				break
			}
		}
		if !isCompleted {
			p.CompletedIDs = append(p.CompletedIDs, "core-01")
			if err := p.Save(); err != nil {
				log.Fatalf("Failed to save progress: %v", err)
			}
			fmt.Println("Progress saved!")
		}
	},
}

var watchCmd = &cobra.Command{
	Use:   "watch",
	Short: "Starts the interactive TUI to watch exercises",
	Run: func(cmd *cobra.Command, args []string) {
		// 1. Load the exercises and progress data first.
		cfg, err := exercises.LoadConfig()
		if err != nil {
			log.Fatalf("Failed to load exercises: %v", err)
		}

		prog, err := progress.Load()
		if err != nil {
			log.Fatalf("Failed to load progress: %v", err)
		}

		// 2. Create the initial TUI model with the loaded data.
		model := tui.NewModel(cfg.Exercises, prog)

		// 3. Create a new Bubble Tea program.
		// This takes our model and prepares it to run.
		p := tea.NewProgram(
			model,
			tea.WithAltScreen(),
			tea.WithMouseCellMotion(),
		)

		// 4. Run the program. This will take over the terminal window
		// until the user quits.
		if _, err := p.Run(); err != nil {
			fmt.Printf("There was an error: %v\n", err)
			os.Exit(1)
		}
	},
}

func main() {
	rootCmd := &cobra.Command{Use: "dockerlings"}
	rootCmd.AddCommand(checkCmd)
	rootCmd.AddCommand(watchCmd) // Add the new watch command here

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
