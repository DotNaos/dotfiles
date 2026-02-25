package app

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

type newOptions struct {
	branch string
	base   string
	clean  bool
	cd     bool
}

type switchOptions struct {
	cd bool
}

func NewRootCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "worktree",
		Short: "Manage Git worktrees",
		Long:  "Create and switch between Git worktrees.",
	}

	cmd.AddCommand(newNewCommand())
	cmd.AddCommand(newSwitchCommand())
	cmd.AddCommand(newListCommand())
	cmd.AddCommand(newCompletionCommand(cmd))
	cmd.SetHelpCommand(&cobra.Command{Hidden: true})

	return cmd
}

func newListCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List branches that currently have worktrees",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			src, err := gitTopLevel()
			if err != nil {
				return errors.New("not inside a git repository")
			}

			for _, branch := range listWorktreeBranches(src) {
				fmt.Println(branch)
			}

			return nil
		},
	}

	return cmd
}

func newNewCommand() *cobra.Command {
	opts := &newOptions{}

	cmd := &cobra.Command{
		Use:               "new --branch <name> [--base <ref>]",
		Aliases:           []string{"create", "add"},
		Short:             "Create a Git worktree with optional local file copy",
		Args:              cobra.RangeArgs(0, 2),
		ValidArgsFunction: completePositionalBaseRef,
		RunE:              runNewWithOptions(opts),
		Example: strings.Join([]string{
			"  worktree new --branch feature/AT-123",
			"  worktree new --branch feature/AT-123 --base main",
			"  worktree new --branch feature/AT-123 --clean",
			"  worktree new --branch feature/AT-123 --cd",
			"  worktree new feature/AT-123 main  # legacy positional form",
			"  eval \"$(worktree new --branch feature/AT-123 --cd)\"",
		}, "\n"),
	}

	cmd.Flags().StringVar(&opts.branch, "branch", "", "New branch name (required)")
	cmd.Flags().StringVarP(&opts.base, "base", "b", "", "Base branch/ref (default: current branch)")
	cmd.Flags().BoolVar(&opts.clean, "clean", false, "Create only tracked files (skip local-only copy)")
	cmd.Flags().BoolVar(&opts.cd, "cd", false, "Print a shell cd command for the created worktree (for eval)")
	_ = cmd.RegisterFlagCompletionFunc("branch", completeBranchFlag)
	_ = cmd.RegisterFlagCompletionFunc("base", completeBaseFlag)

	return cmd
}

func newSwitchCommand() *cobra.Command {
	opts := &switchOptions{}

	cmd := &cobra.Command{
		Use:               "switch <branch-or-path>",
		Aliases:           []string{"cd"},
		Short:             "Resolve an existing worktree by branch or path",
		Args:              cobra.ExactArgs(1),
		ValidArgsFunction: completeSwitchTarget,
		RunE: func(_ *cobra.Command, args []string) error {
			target, err := resolveSwitchTarget(args[0])
			if err != nil {
				return err
			}

			if opts.cd {
				fmt.Printf("cd %s\n", shellQuote(target))
				return nil
			}

			fmt.Println(target)
			return nil
		},
		Example: strings.Join([]string{
			"  worktree switch feature/AT-123",
			"  worktree switch ../myrepo.worktrees/feature-AT-123",
			"  eval \"$(worktree switch feature/AT-123 --cd)\"",
		}, "\n"),
	}

	cmd.Flags().BoolVar(&opts.cd, "cd", false, "Print a shell cd command for the resolved worktree (for eval)")

	return cmd
}

func runNewWithOptions(opts *newOptions) func(cmd *cobra.Command, args []string) error {
	return func(cmd *cobra.Command, args []string) error {
		branch := strings.TrimSpace(opts.branch)
		if len(args) > 0 {
			if cmd.Flags().Changed("branch") {
				return errors.New("branch specified both as argument and --branch")
			}
			branch = strings.TrimSpace(args[0])
		}

		if branch == "" || strings.HasPrefix(branch, "-") {
			return errors.New("missing required branch (use --branch <name>)")
		}

		base := strings.TrimSpace(opts.base)
		if len(args) > 1 {
			if cmd.Flags().Changed("base") {
				return errors.New("base specified both as argument and --base")
			}
			base = strings.TrimSpace(args[len(args)-1])
		}

		return runNew(branch, base, opts.clean, opts.cd)
	}
}

func completeBranchFlag(_ *cobra.Command, _ []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	return completeGitRefs(toComplete)
}

func completePositionalBaseRef(_ *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	if len(args) > 1 {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}

	src, err := gitTopLevel()
	if err != nil {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}

	return filterByPrefix(listGitRefs(src), toComplete), cobra.ShellCompDirectiveNoFileComp
}

func completeBaseFlag(_ *cobra.Command, _ []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	return completeGitRefs(toComplete)
}

func completeGitRefs(toComplete string) ([]string, cobra.ShellCompDirective) {
	src, err := gitTopLevel()
	if err != nil {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}
	return filterByPrefix(listGitRefs(src), toComplete), cobra.ShellCompDirectiveNoFileComp
}

func completeSwitchTarget(_ *cobra.Command, _ []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	src, err := gitTopLevel()
	if err != nil {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}

	return filterByPrefix(listWorktreeBranches(src), toComplete), cobra.ShellCompDirectiveNoFileComp
}

func runNew(branch, base string, clean, cd bool) error {
	src, err := gitTopLevel()
	if err != nil {
		return errors.New("not inside a git repository")
	}

	branchAlreadyExists, base, err := resolveBranchAndBase(src, branch, base)
	if err != nil {
		return err
	}

	repoName := filepath.Base(src)
	branchSlug := strings.ReplaceAll(branch, "/", "-")
	wtRoot := filepath.Join(filepath.Dir(src), repoName+".worktrees")
	dst := filepath.Join(wtRoot, branchSlug)

	if err := ensureWorktreeTarget(wtRoot, dst); err != nil {
		return err
	}

	if err := addWorktree(src, dst, branch, base, branchAlreadyExists, cd); err != nil {
		return err
	}

	if !clean {
		if err := copyLocalOnlyFiles(src, dst); err != nil {
			return err
		}
	}

	if cd {
		fmt.Printf("cd %s\n", shellQuote(dst))
		return nil
	}

	fmt.Printf("✅ Worktree created: %s\n", dst)
	if clean {
		fmt.Println("   ↳ Skipped local-only file copy (--clean)")
	} else {
		fmt.Println("   ↳ Local-only files copied (excluding heavy/cache folders)")
	}

	return nil
}

func resolveBranchAndBase(src, branch, base string) (bool, string, error) {
	branchAlreadyExists := localBranchExists(src, branch)
	if branchAlreadyExists {
		return true, "", nil
	}

	if base == "" {
		resolved, err := defaultBase(src)
		if err != nil {
			return false, "", err
		}
		base = resolved
	}

	if !refExists(src, base) {
		return false, "", fmt.Errorf("base ref not found: %s", base)
	}

	return false, base, nil
}

func ensureWorktreeTarget(wtRoot, dst string) error {
	if _, err := os.Stat(dst); err == nil {
		return fmt.Errorf("target path already exists: %s", dst)
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}

	if err := os.MkdirAll(wtRoot, 0o755); err != nil {
		return err
	}

	return nil
}

func addWorktree(src, dst, branch, base string, branchAlreadyExists, quiet bool) error {
	if branchAlreadyExists {
		if quiet {
			return runCmdQuiet("", "git", "-C", src, "worktree", "add", dst, branch)
		}
		return runCmd("", "git", "-C", src, "worktree", "add", dst, branch)
	}

	if quiet {
		return runCmdQuiet("", "git", "-C", src, "worktree", "add", dst, "-b", branch, base)
	}
	return runCmd("", "git", "-C", src, "worktree", "add", dst, "-b", branch, base)
}

func resolveSwitchTarget(target string) (string, error) {
	if target == "" {
		return "", errors.New("missing switch target")
	}

	src, err := gitTopLevel()
	if err != nil {
		return "", errors.New("not inside a git repository")
	}

	// Prefer branch lookup from actual `git worktree list` output,
	// even when the branch name contains '/'.
	if path := findWorktreePathByBranch(src, target); path != "" {
		return path, nil
	}

	if strings.ContainsRune(target, os.PathSeparator) || target == "." || target == ".." {
		abs, err := filepath.Abs(target)
		if err != nil {
			return "", err
		}
		if _, err := os.Stat(abs); err != nil {
			return "", fmt.Errorf("worktree path not found: %s", abs)
		}
		return abs, nil
	}

	return "", fmt.Errorf("worktree not found for target: %s", target)
}

func findWorktreePathByBranch(src, branch string) string {
	out, err := runCmdOutput("", "git", "-C", src, "worktree", "list", "--porcelain")
	if err != nil {
		return ""
	}

	var currentPath string
	needle := "refs/heads/" + branch
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			currentPath = ""
			continue
		}
		if strings.HasPrefix(line, "worktree ") {
			currentPath = strings.TrimSpace(strings.TrimPrefix(line, "worktree "))
			continue
		}
		if line == "branch "+needle {
			return currentPath
		}
	}

	return ""
}

func listWorktreePaths(src string) []string {
	out, err := runCmdOutput("", "git", "-C", src, "worktree", "list", "--porcelain")
	if err != nil {
		return nil
	}

	var paths []string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "worktree ") {
			paths = append(paths, strings.TrimSpace(strings.TrimPrefix(line, "worktree ")))
		}
	}
	return paths
}

func listWorktreeBranches(src string) []string {
	out, err := runCmdOutput("", "git", "-C", src, "worktree", "list", "--porcelain")
	if err != nil {
		return nil
	}

	allRefs := listGitRefs(src)
	refSet := make(map[string]struct{}, len(allRefs))
	for _, ref := range allRefs {
		refSet[ref] = struct{}{}
	}

	seen := map[string]struct{}{}
	var branches []string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "branch refs/heads/") {
			continue
		}

		branch := strings.TrimPrefix(line, "branch refs/heads/")
		if branch == "" {
			continue
		}
		if _, ok := refSet[branch]; !ok {
			continue
		}
		if _, ok := seen[branch]; ok {
			continue
		}

		seen[branch] = struct{}{}
		branches = append(branches, branch)
	}

	return branches
}

func gitTopLevel() (string, error) {
	out, err := runCmdOutput("", "git", "rev-parse", "--show-toplevel")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

func defaultBase(src string) (string, error) {
	if out, err := runCmdOutput("", "git", "-C", src, "branch", "--show-current"); err == nil {
		if current := strings.TrimSpace(out); current != "" {
			return current, nil
		}
	}

	if refExists(src, "dev") {
		return "dev", nil
	}
	if refExists(src, "main") {
		return "main", nil
	}
	if refExists(src, "HEAD") {
		return "HEAD", nil
	}
	return "", errors.New("could not determine default base ref")
}

func refExists(src, ref string) bool {
	err := runCmd("", "git", "-C", src, "rev-parse", "--verify", "--quiet", ref+"^{commit}")
	return err == nil
}

func localBranchExists(src, branch string) bool {
	err := runCmd("", "git", "-C", src, "show-ref", "--verify", "--quiet", "refs/heads/"+branch)
	return err == nil
}

func copyLocalOnlyFiles(src, dst string) error {
	rs, err := exec.LookPath("rsync")
	if err == nil && rs != "" {
		cmd := fmt.Sprintf("git -C %q ls-files -z --others --ignored --exclude-standard | rsync -a --from0 --files-from=- --exclude '.git' --exclude '.jj' --exclude 'node_modules' --exclude 'bin' --exclude 'obj' %q/ %q/", src, src, dst)
		return runCmd("", "bash", "-lc", cmd)
	}

	return copyLocalOnlyFilesFallback(src, dst)
}

func copyLocalOnlyFilesFallback(src, dst string) error {
	out, err := runCmdOutput("", "git", "-C", src, "ls-files", "-z", "--others", "--ignored", "--exclude-standard")
	if err != nil {
		return err
	}

	for _, rel := range strings.Split(out, "\x00") {
		if rel == "" || isExcludedLocalPath(rel) {
			continue
		}

		srcPath := filepath.Join(src, rel)
		dstPath := filepath.Join(dst, rel)

		if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
			return err
		}
		if err := runCmd("", "cp", "-a", srcPath, dstPath); err != nil {
			return err
		}
	}

	return nil
}

func isExcludedLocalPath(rel string) bool {
	excludedPrefixes := []string{".git", ".jj", "node_modules", "bin", "obj"}
	for _, prefix := range excludedPrefixes {
		if rel == prefix || strings.HasPrefix(rel, prefix+"/") {
			return true
		}
	}
	return false
}

func listGitRefs(src string) []string {
	out, err := runCmdOutput("", "git", "-C", src, "for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes")
	if err != nil {
		return nil
	}

	var refs []string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			refs = append(refs, line)
		}
	}
	return refs
}

func filterByPrefix(values []string, prefix string) []string {
	if prefix == "" {
		return values
	}

	var filtered []string
	for _, value := range values {
		if strings.HasPrefix(value, prefix) {
			filtered = append(filtered, value)
		}
	}
	return filtered
}

func shellQuote(value string) string {
	if value == "" {
		return "''"
	}
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func runCmd(dir, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runCmdQuiet(dir, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("command failed: %s %s", name, strings.Join(args, " "))
	}
	return nil
}

func runCmdOutput(dir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	out, err := cmd.Output()
	return string(out), err
}
