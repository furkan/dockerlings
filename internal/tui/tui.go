// internal/tui/tui.go
package tui

import (
	"fmt"
	"log"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/furkan/dockerlings/internal/exercises"
	"github.com/furkan/dockerlings/internal/progress"
	"github.com/furkan/dockerlings/internal/util"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/glamour"
	"github.com/charmbracelet/lipgloss"
)

// ──────────────────────────────────────────────────────────────
//
//	Constants
//
// ──────────────────────────────────────────────────────────────
const (
	minPaneHeight      = 5
	minTermWidth       = 80
	minTermHeight      = 24
	markdownWordWrap   = 100
	defaultListWidth   = 30
	maxListWidth       = 50
	listWidthDivisor   = 6
	footerHeight       = 3
	footerRightPadding = 3
	borderOverhead     = 6  // Total padding and borders for both panes
	minContentWidth    = 20 // Minimum width for content pane
	symbolCompleted    = "✓"
	symbolLocked       = "x"
	symbolSelected     = ">"
)

// ──────────────────────────────────────────────────────────────
//
//	Styles
//
// ──────────────────────────────────────────────────────────────
type styles struct {
	docStyle        lipgloss.Style
	basePaneStyle   lipgloss.Style
	listHeaderStyle lipgloss.Style
	listItemStyle   lipgloss.Style
	completedStyle  lipgloss.Style
	lockedStyle     lipgloss.Style
	selectedStyle   lipgloss.Style
	statusStyle     lipgloss.Style
	helpStyle       lipgloss.Style
	errorStyle      lipgloss.Style
}

func initStyles() styles {
	return styles{
		docStyle: lipgloss.NewStyle().PaddingLeft(1),
		basePaneStyle: lipgloss.NewStyle().
			Padding(1, 2).
			Border(lipgloss.RoundedBorder()).
			BorderStyle(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("63")),
		listHeaderStyle: lipgloss.NewStyle().
			Bold(true).
			Padding(0, 1).
			Background(lipgloss.Color("63")),
		listItemStyle:  lipgloss.NewStyle().PaddingLeft(2),
		completedStyle: lipgloss.NewStyle().PaddingLeft(1).Foreground(lipgloss.Color("78")),
		lockedStyle:    lipgloss.NewStyle().PaddingLeft(1).Foreground(lipgloss.Color("240")),
		selectedStyle:  lipgloss.NewStyle().PaddingLeft(1).Foreground(lipgloss.Color("226")),
		statusStyle: lipgloss.NewStyle().
			Padding(0, 1).
			Background(lipgloss.Color("237")),
		helpStyle: lipgloss.NewStyle().
			Padding(0, 1).
			Background(lipgloss.Color("240")),
		errorStyle: lipgloss.NewStyle().
			Foreground(lipgloss.Color("196")),
	}
}

var (
	markdownRenderer *glamour.TermRenderer
	appStyles        = initStyles()
)

func init() {
	var err error
	markdownRenderer, err = glamour.NewTermRenderer(
		glamour.WithAutoStyle(),
		glamour.WithWordWrap(markdownWordWrap),
	)
	if err != nil {
		panic(fmt.Sprintf("Failed to initialize markdown renderer: %v", err))
	}
}

// ──────────────────────────────────────────────────────────────
//
//	Messages
//
// ──────────────────────────────────────────────────────────────
type checkResultMsg struct {
	success bool
	id      string
}

// ──────────────────────────────────────────────────────────────
//
//	Model
//
// ──────────────────────────────────────────────────────────────
type model struct {
	exercises     []exercises.Exercise
	progress      *progress.Progress
	spinner       spinner.Model
	viewport      viewport.Model
	cursor        int
	statusMessage string
	isChecking    bool
	inHint        bool
	termWidth     int
	termHeight    int
}

// NewModel creates a new TUI model with the given exercises and progress
func NewModel(exs []exercises.Exercise, prog *progress.Progress) model {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	vp := viewport.New(minTermWidth, minTermHeight)

	m := model{
		exercises:     exs,
		progress:      prog,
		spinner:       s,
		viewport:      vp,
		cursor:        findFirstIncompleteExercise(exs, prog),
		statusMessage: "Ready.",
		termWidth:     minTermWidth,
		termHeight:    minTermHeight,
	}
	m.loadPrompt()
	return m
}

// Init initializes the model
func (m model) Init() tea.Cmd {
	return nil
}

// ──────────────────────────────────────────────────────────────
//
//	Update
//
// ──────────────────────────────────────────────────────────────

// Update handles incoming messages and updates the model
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.handleWindowResize(msg)
		return m, nil

	case tea.KeyMsg:
		if cmd := m.handleKeyPress(msg); cmd != nil {
			return m, cmd
		}

	case checkResultMsg:
		m.handleCheckResult(msg)
	}

	// Update components
	cmds = append(cmds, m.updateComponents(msg)...)

	return m, tea.Batch(cmds...)
}

// handleWindowResize updates the model dimensions based on terminal size
func (m *model) handleWindowResize(msg tea.WindowSizeMsg) {
	m.termWidth, m.termHeight = msg.Width, msg.Height

	paneHeight := m.calculatePaneHeight()
	listPaneWidth := m.calculateListPaneWidth()

	// Account for all borders and padding
	availableWidth := max(m.termWidth-borderOverhead, minTermWidth)

	viewportWidth := max(availableWidth-listPaneWidth, minContentWidth)
	m.viewport.Width = viewportWidth
	m.viewport.Height = paneHeight
}

// handleKeyPress processes keyboard input
func (m *model) handleKeyPress(msg tea.KeyMsg) tea.Cmd {
	key := msg.String()

	// Global controls
	if key == "ctrl+c" || key == "q" {
		return tea.Quit
	}

	// Ignore input while checking
	if m.isChecking {
		return nil
	}

	// Exit hint view
	if m.inHint {
		m.loadPrompt()
		return nil
	}

	// Handle navigation and actions
	switch key {
	case "up", "k":
		return m.moveCursorUp()
	case "down", "j":
		return m.moveCursorDown()
	case "h":
		m.loadHint()
	case "c":
		return m.checkExercise()
	}

	return nil
}

// handleCheckResult processes the result of an exercise check
func (m *model) handleCheckResult(msg checkResultMsg) {
	m.isChecking = false
	if msg.success {
		m.statusMessage = "Correct! Exercise complete."
		m.progress.Add(msg.id)
		_ = m.progress.Save()
	} else {
		m.statusMessage = appStyles.errorStyle.Render("Incorrect. Try again.")
	}
}

// updateComponents updates viewport and spinner
func (m *model) updateComponents(msg tea.Msg) []tea.Cmd {
	var cmds []tea.Cmd

	// Update viewport
	var cmd tea.Cmd
	m.viewport, cmd = m.viewport.Update(msg)
	cmds = append(cmds, cmd)

	// Update spinner when checking
	if m.isChecking {
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)
	}

	return cmds
}

// ──────────────────────────────────────────────────────────────
//
//	View
//
// ──────────────────────────────────────────────────────────────

// View renders the TUI
func (m model) View() string {
	paneHeight := m.calculatePaneHeight()
	listPaneWidth := m.calculateListPaneWidth()

	// Calculate available width accounting for all borders and padding
	availableWidth := max(m.termWidth-borderOverhead, minTermWidth)

	rightPaneWidth := max(availableWidth-listPaneWidth, minContentWidth)

	leftPane := m.renderLeftPane(paneHeight, listPaneWidth)
	rightPane := m.renderRightPane(paneHeight, rightPaneWidth)
	footer := m.renderFooter(m.termWidth)

	panes := lipgloss.JoinHorizontal(lipgloss.Top, leftPane, rightPane)
	final := lipgloss.JoinVertical(lipgloss.Left, panes, footer)

	return appStyles.docStyle.Render(final)
}

// renderLeftPane creates the exercise list pane
func (m model) renderLeftPane(height, width int) string {
	content := lipgloss.JoinVertical(lipgloss.Left,
		appStyles.listHeaderStyle.Render("Exercises"),
		m.renderExerciseList(),
	)

	return appStyles.basePaneStyle.
		Height(height).
		Width(width).
		Render(content)
}

// renderRightPane creates the content pane
func (m model) renderRightPane(height, width int) string {
	return appStyles.basePaneStyle.
		Height(height).
		Width(width).
		Render(m.viewport.View())
}

// renderFooter creates the status and help bar
func (m model) renderFooter(totalWidth int) string {
	helpTxt := appStyles.helpStyle.Render("(h)int │ (c)heck │ (q)uit")
	statusTxt := m.getStatusText()

	statusRendered := appStyles.statusStyle.Render(statusTxt)

	// Calculate spacer width based on actual rendered widths
	usedWidth := lipgloss.Width(statusRendered) + lipgloss.Width(helpTxt)
	spacerWidth := totalWidth - usedWidth - footerRightPadding
	if spacerWidth < 0 {
		spacerWidth = 0
	}

	return lipgloss.JoinHorizontal(lipgloss.Left,
		statusRendered,
		lipgloss.NewStyle().Width(spacerWidth).Render(""),
		helpTxt,
	)
}

// renderExerciseList builds the exercise list view
func (m model) renderExerciseList() string {
	var builder strings.Builder

	for i, ex := range m.exercises {
		item := m.formatExerciseItem(i, ex)
		builder.WriteString(item)
		builder.WriteString("\n")
	}

	return builder.String()
}

// formatExerciseItem formats a single exercise list item
func (m model) formatExerciseItem(index int, ex exercises.Exercise) string {
	if index == m.cursor {
		return appStyles.selectedStyle.Render(symbolSelected + " " + ex.Title)
	}

	if m.progress.IsCompleted(ex.ID) {
		return appStyles.completedStyle.Render(symbolCompleted + " " + ex.Title)
	}

	if ex.DependsOn != "" && !m.progress.IsCompleted(ex.DependsOn) {
		return appStyles.lockedStyle.Render(symbolLocked + " " + ex.Title)
	}

	return appStyles.listItemStyle.Render(ex.Title)
}

// getStatusText returns the current status message with spinner if checking
func (m model) getStatusText() string {
	if m.isChecking {
		return m.spinner.View() + " " + m.statusMessage
	}
	return m.statusMessage
}

// ──────────────────────────────────────────────────────────────
//
//	Navigation & Actions
//
// ──────────────────────────────────────────────────────────────

// moveCursorUp moves the cursor up in the exercise list
func (m *model) moveCursorUp() tea.Cmd {
	if m.cursor > 0 {
		m.cursor--
		m.loadPrompt()
	}
	return nil
}

// moveCursorDown moves the cursor down in the exercise list
func (m *model) moveCursorDown() tea.Cmd {
	if m.cursor < len(m.exercises)-1 {
		m.cursor++
		m.loadPrompt()
	}
	return nil
}

// checkExercise initiates the check process for the current exercise
func (m *model) checkExercise() tea.Cmd {
	cur := m.exercises[m.cursor]

	if cur.DependsOn != "" && !m.progress.IsCompleted(cur.DependsOn) {
		m.statusMessage = appStyles.errorStyle.Render("Complete previous exercise first.")
		return nil
	}

	m.isChecking = true
	m.statusMessage = fmt.Sprintf("Verifying '%s'...", cur.Title)

	return tea.Batch(m.runCheck(), m.spinner.Tick)
}

// loadPrompt loads the exercise prompt into the viewport
func (m *model) loadPrompt() {
	m.inHint = false
	id := m.exercises[m.cursor].ID

	content, err := exercises.LoadFileContent(id, "prompt.md")
	if err != nil {
		m.setViewportError("Error loading prompt: %v", err)
		return
	}

	renderedContent, err := markdownRenderer.Render(content)
	if err != nil {
		m.setViewportError("Error rendering markdown: %v", err)
		return
	}

	m.viewport.SetContent(renderedContent)
	m.viewport.GotoTop()
	m.statusMessage = "Ready. Press (c) to check or (h) for a hint."
}

// loadHint loads the exercise hint into the viewport
func (m *model) loadHint() {
	id := m.exercises[m.cursor].ID

	content, err := exercises.LoadFileContent(id, "hint.md")
	if err != nil {
		m.setViewportError("Error loading hint: %v", err)
		return
	}

	renderedContent, err := markdownRenderer.Render("HINT\n\n" + content)
	if err != nil {
		m.setViewportError("Error rendering markdown: %v", err)
		return
	}

	m.viewport.SetContent(renderedContent)
	m.viewport.GotoTop()
	m.inHint = true
	m.statusMessage = "Press any key to return to prompt."
}

// runCheck executes the exercise check script
func (m model) runCheck() tea.Cmd {
	return func() tea.Msg {
		cur := m.exercises[m.cursor]

		root, err := util.GetProjectRoot()
		if err != nil {
			log.Printf("Error finding project root: %v", err)
			return checkResultMsg{success: false, id: cur.ID}
		}

		exerciseDir := filepath.Join(root, "exercises", cur.ID)
		script := filepath.Join(exerciseDir, "check.sh")

		cmd := exec.Command("/bin/bash", script)
		cmd.Dir = exerciseDir // ← THIS IS THE FIX

		err = cmd.Run()
		return checkResultMsg{success: err == nil, id: cur.ID}
	}
}

// ──────────────────────────────────────────────────────────────
//
//	Helper Functions
//
// ──────────────────────────────────────────────────────────────

// findFirstIncompleteExercise returns the index of the first incomplete exercise
func findFirstIncompleteExercise(exs []exercises.Exercise, prog *progress.Progress) int {
	for i, ex := range exs {
		if !prog.IsCompleted(ex.ID) {
			return i
		}
	}
	return 0
}

// calculatePaneHeight returns the appropriate pane height based on terminal size
func (m model) calculatePaneHeight() int {
	height := m.termHeight - footerHeight - borderOverhead
	if height < minPaneHeight {
		return minPaneHeight
	}
	return height
}

// calculateListPaneWidth returns the appropriate list pane width
func (m model) calculateListPaneWidth() int {
	width := m.termWidth / listWidthDivisor
	// Ensure list pane doesn't exceed reasonable bounds
	if width < defaultListWidth {
		return defaultListWidth
	}
	// Cap at maxListWidth to leave room for content pane
	if width > maxListWidth {
		return maxListWidth
	}
	return width
}

// setViewportError sets an error message in the viewport
func (m *model) setViewportError(format string, err error) {
	m.viewport.SetContent(appStyles.errorStyle.Render(fmt.Sprintf(format, err)))
}
