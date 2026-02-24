package app

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

type options struct {
	branch string
	base   string
	clean  bool
}

func NewRootCommand() *cobra.Command {
	opts := &options{}

	cmd := &cobra.Command{
		Use:               "wt-new --branch <name> [--base <ref>]",
		Short:             "Create a Git worktree with optional local file copy",
		Args:              cobra.RangeArgs(0, 2),
		ValidArgsFunction: completePositionalBaseRef,
		RunE:              runWithOptions(opts),
		Example: strings.Join([]string{
			"  wt-new --branch feature/AT-123",
			"  wt-new --branch feature/AT-123 --base main",
			"  wt-new --branch feature/AT-123 --clean",
			"  wt-new feature/AT-123 main  # legacy positional form",
		}, "\n"),
	}

	cmd.Flags().StringVar(&opts.branch, "branch", "", "New branch name (required)")
	cmd.Flags().StringVarP(&opts.base, "base", "b", "", "Base branch/ref (default: current branch)")
	cmd.Flags().BoolVar(&opts.clean, "clean", false, "Create only tracked files (skip local-only copy)")
	_ = cmd.RegisterFlagCompletionFunc("branch", completeBranchFlag)
	_ = cmd.RegisterFlagCompletionFunc("base", completeBaseFlag)
	cmd.AddCommand(newCompletionCommand(cmd))
	cmd.SetHelpCommand(&cobra.Command{Hidden: true})

	return cmd
}

func runWithOptions(opts *options) func(cmd *cobra.Command, args []string) error {
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

		return run(branch, base, opts.clean)
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

	// For UX, suggest existing refs even for the first argument.
	// Users can still type any new branch name freely.
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

func run(branch, base string, clean bool) error {
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

	if err := addWorktree(src, dst, branch, base, branchAlreadyExists); err != nil {
		return err
	}

	if !clean {
		if err := copyLocalOnlyFiles(src, dst); err != nil {
			return err
		}
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

func addWorktree(src, dst, branch, base string, branchAlreadyExists bool) error {
	if branchAlreadyExists {
		return runCmd("", "git", "-C", src, "worktree", "add", dst, branch)
	}

	return runCmd("", "git", "-C", src, "worktree", "add", dst, "-b", branch, base)
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

func runCmd(dir, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runCmdOutput(dir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	out, err := cmd.Output()
	return string(out), err
}
