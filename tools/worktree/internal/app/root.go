package app

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
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

type listOptions struct {
	plain bool
}

type removeOptions struct {
	branch string
	path   string
	force  bool
}

type worktreeInfo struct {
	path   string
	branch string
	main   bool
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
	cmd.AddCommand(newRemoveCommand())
	cmd.AddCommand(newSyncCommand())
	cmd.AddCommand(newCompletionCommand(cmd))
	cmd.SetHelpCommand(&cobra.Command{Hidden: true})

	return cmd
}

func newListCommand() *cobra.Command {
	opts := &listOptions{}

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List branches that currently have worktrees",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			src, err := gitTopLevel()
			if err != nil {
				return errors.New("not inside a git repository")
			}

			for _, info := range listWorktrees(src) {
				if opts.plain || !info.main {
					fmt.Println(info.branch)
					continue
				}

				fmt.Printf("* %s (main)\n", info.branch)
			}

			return nil
		},
	}

	cmd.Flags().BoolVar(&opts.plain, "plain", false, "Print only raw branch names")

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

func newRemoveCommand() *cobra.Command {
	opts := &removeOptions{}

	cmd := &cobra.Command{
		Use:               "remove [branch-or-path]",
		Aliases:           []string{"rm", "delete"},
		Short:             "Remove an existing worktree by branch or path",
		Args:              cobra.RangeArgs(0, 1),
		ValidArgsFunction: completeSwitchTarget,
		RunE:              runRemoveWithOptions(opts),
		Example: strings.Join([]string{
			"  worktree remove feature/AT-123",
			"  worktree remove --branch feature/AT-123",
			"  worktree remove --path ../myrepo.worktrees/feature-AT-123",
			"  worktree remove --force feature/AT-123",
		}, "\n"),
	}

	cmd.Flags().StringVar(&opts.branch, "branch", "", "Branch name whose worktree should be removed")
	cmd.Flags().StringVar(&opts.path, "path", "", "Exact worktree path to remove")
	cmd.Flags().BoolVarP(&opts.force, "force", "f", false, "Force removal even with uncommitted changes")
	_ = cmd.RegisterFlagCompletionFunc("branch", completeSwitchTarget)
	_ = cmd.RegisterFlagCompletionFunc("path", completeWorktreePath)

	return cmd
}

func newSyncCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "sync",
		Short: "Sync existing worktrees into VS Code workspace folders",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			src, err := gitTopLevel()
			if err != nil {
				return errors.New("not inside a git repository")
			}

			baseRoot := mainWorktreePath(src)
			if baseRoot == "" {
				return errors.New("could not resolve main worktree root")
			}

			workspaceFile := firstWorkspaceFile(baseRoot)
			if workspaceFile == "" {
				fmt.Println("No .code-workspace file found in main worktree root; nothing to sync.")
				return nil
			}

			infos := listWorktrees(baseRoot)
			for _, info := range infos {
				if err := updateWorkspaceFolders(baseRoot, info.path, true); err != nil {
					return err
				}
			}

			fmt.Printf("✅ Workspace synced: %s\n", workspaceFile)
			return nil
		},
	}

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
	src = baseWorktreeRoot(src)

	return filterByPrefix(listWorktreeBranches(src), toComplete), cobra.ShellCompDirectiveNoFileComp
}

func completeWorktreePath(_ *cobra.Command, _ []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	src, err := gitTopLevel()
	if err != nil {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}
	src = baseWorktreeRoot(src)

	return filterByPrefix(listWorktreePaths(src), toComplete), cobra.ShellCompDirectiveNoFileComp
}

func runRemoveWithOptions(opts *removeOptions) func(cmd *cobra.Command, args []string) error {
	return func(cmd *cobra.Command, args []string) error {
		src, err := gitTopLevel()
		if err != nil {
			return errors.New("not inside a git repository")
		}
		src = baseWorktreeRoot(src)

		branch := strings.TrimSpace(opts.branch)
		path := strings.TrimSpace(opts.path)

		if len(args) > 0 {
			if cmd.Flags().Changed("branch") || cmd.Flags().Changed("path") {
				return errors.New("target specified both positionally and via --branch/--path")
			}

			resolved, resolveErr := resolveSwitchTarget(args[0])
			if resolveErr != nil {
				return resolveErr
			}
			path = resolved
		} else {
			if branch != "" && path != "" {
				return errors.New("use only one of --branch or --path")
			}

			if branch != "" {
				resolved := findWorktreePathByBranch(src, branch)
				if resolved == "" {
					return fmt.Errorf("worktree not found for branch: %s", branch)
				}
				path = resolved
			}

			if path == "" {
				return errors.New("missing target (use positional, --branch, or --path)")
			}

			abs, absErr := filepath.Abs(path)
			if absErr == nil {
				path = abs
			}
		}

		if err := removeWorktree(src, path, opts.force); err != nil {
			return err
		}

		if err := updateWorkspaceFolders(src, path, false); err != nil {
			fmt.Fprintf(os.Stderr, "warning: failed to update VS Code workspace: %v\n", err)
		}

		fmt.Printf("✅ Worktree removed: %s\n", path)
		return nil
	}
}

func runNew(branch, base string, clean, cd bool) error {
	src, err := gitTopLevel()
	if err != nil {
		return errors.New("not inside a git repository")
	}
	src = baseWorktreeRoot(src)

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

	if err := updateWorkspaceFolders(src, dst, true); err != nil {
		fmt.Fprintf(os.Stderr, "warning: failed to update VS Code workspace: %v\n", err)
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

func removeWorktree(src, path string, force bool) error {
	if force {
		if err := runCmd("", "git", "-C", src, "worktree", "remove", "--force", path); err != nil {
			return err
		}
		return nil
	}

	if err := runCmd("", "git", "-C", src, "worktree", "remove", path); err != nil {
		return err
	}

	return nil
}

func resolveSwitchTarget(target string) (string, error) {
	if target == "" {
		return "", errors.New("missing switch target")
	}

	src, err := gitTopLevel()
	if err != nil {
		return "", errors.New("not inside a git repository")
	}
	src = baseWorktreeRoot(src)

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
	for _, info := range listWorktrees(src) {
		if info.branch == branch {
			return info.path
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
	infos := listWorktrees(src)
	if len(infos) == 0 {
		return nil
	}

	allRefs := listGitRefs(src)
	refSet := make(map[string]struct{}, len(allRefs))
	for _, ref := range allRefs {
		refSet[ref] = struct{}{}
	}

	seen := map[string]struct{}{}
	var branches []string
	for _, info := range infos {
		if info.branch == "" {
			continue
		}
		if _, ok := refSet[info.branch]; !ok {
			continue
		}
		if _, ok := seen[info.branch]; ok {
			continue
		}

		seen[info.branch] = struct{}{}
		branches = append(branches, info.branch)
	}

	return branches
}

func listWorktrees(src string) []worktreeInfo {
	out, err := runCmdOutput("", "git", "-C", src, "worktree", "list", "--porcelain")
	if err != nil {
		return nil
	}

	mainPath := mainWorktreePath(src)

	var infos []worktreeInfo
	var current worktreeInfo
	flush := func() {
		if current.path != "" && current.branch != "" {
			infos = append(infos, current)
		}
		current = worktreeInfo{}
	}

	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			flush()
			continue
		}

		if strings.HasPrefix(line, "worktree ") {
			current.path = strings.TrimSpace(strings.TrimPrefix(line, "worktree "))
			current.main = (mainPath != "" && current.path == mainPath)
			continue
		}

		if strings.HasPrefix(line, "branch refs/heads/") {
			current.branch = strings.TrimPrefix(line, "branch refs/heads/")
			continue
		}
	}
	flush()

	return infos
}

func mainWorktreePath(src string) string {
	out, err := runCmdOutput("", "git", "-C", src, "rev-parse", "--path-format=absolute", "--git-common-dir")
	if err != nil {
		return ""
	}

	gitCommonDir := strings.TrimSpace(out)
	if gitCommonDir == "" {
		return ""
	}

	return filepath.Dir(gitCommonDir)
}

func baseWorktreeRoot(src string) string {
	mainRoot := mainWorktreePath(src)
	if mainRoot == "" {
		return src
	}

	return mainRoot
}

func updateWorkspaceFolders(src, worktreePath string, add bool) error {
	// TODO: Move workspace sync behavior behind user config (e.g. ~/.config/worktree/config.*)
	// and disable it by default; later expose an explicit CLI flag to enable it.
	workspaceFile := firstWorkspaceFile(src)
	if workspaceFile == "" {
		return nil
	}

	content, err := os.ReadFile(workspaceFile)
	if err != nil {
		return err
	}

	parsed := sanitizeWorkspaceJSON(content)

	var root map[string]any
	if err := json.Unmarshal(parsed, &root); err != nil {
		return err
	}

	workspaceDir := filepath.Dir(workspaceFile)
	targetAbs, err := filepath.Abs(worktreePath)
	if err != nil {
		return err
	}

	entries := folderEntries(root["folders"])
	if add {
		entries = addFolderEntry(entries, workspaceDir, targetAbs)
	} else {
		entries = removeFolderEntry(entries, workspaceDir, targetAbs)
	}

	root["folders"] = entriesToAny(entries)

	updated, err := json.MarshalIndent(root, "", "  ")
	if err != nil {
		return err
	}

	updated = append(updated, '\n')
	return os.WriteFile(workspaceFile, updated, 0o644)
}

func sanitizeWorkspaceJSON(content []byte) []byte {
	noComments := stripLineComments(content)
	return stripTrailingCommas(noComments)
}

func stripLineComments(content []byte) []byte {
	var out []byte
	inString := false
	escaped := false

	for i := 0; i < len(content); i++ {
		ch := content[i]

		if inString {
			out = append(out, ch)
			if escaped {
				escaped = false
				continue
			}
			if ch == '\\' {
				escaped = true
				continue
			}
			if ch == '"' {
				inString = false
			}
			continue
		}

		if ch == '"' {
			inString = true
			out = append(out, ch)
			continue
		}

		if ch == '/' && i+1 < len(content) && content[i+1] == '/' {
			for i < len(content) && content[i] != '\n' {
				i++
			}
			if i < len(content) {
				out = append(out, content[i])
			}
			continue
		}

		out = append(out, ch)
	}

	return out
}

func stripTrailingCommas(content []byte) []byte {
	out := make([]byte, 0, len(content))
	inString := false
	escaped := false

	for i := 0; i < len(content); i++ {
		ch := content[i]

		if inString {
			out = append(out, ch)
			if escaped {
				escaped = false
				continue
			}
			if ch == '\\' {
				escaped = true
				continue
			}
			if ch == '"' {
				inString = false
			}
			continue
		}

		if ch == '"' {
			inString = true
			out = append(out, ch)
			continue
		}

		if ch == ',' {
			j := i + 1
			for j < len(content) {
				next := content[j]
				if next == ' ' || next == '\t' || next == '\n' || next == '\r' {
					j++
					continue
				}
				break
			}
			if j < len(content) && (content[j] == ']' || content[j] == '}') {
				continue
			}
		}

		out = append(out, ch)
	}

	return out
}

func firstWorkspaceFile(baseRoot string) string {
	if strings.TrimSpace(baseRoot) == "" {
		return ""
	}

	files, err := filepath.Glob(filepath.Join(baseRoot, "*.code-workspace"))
	if err != nil || len(files) == 0 {
		return ""
	}

	sort.Strings(files)
	return files[0]
}

type workspaceFolderEntry struct {
	name string
	path string
}

func folderEntries(value any) []workspaceFolderEntry {
	rawFolders, ok := value.([]any)
	if !ok {
		return nil
	}

	var entries []workspaceFolderEntry
	for _, item := range rawFolders {
		asMap, ok := item.(map[string]any)
		if !ok {
			continue
		}

		pathValue, _ := asMap["path"].(string)
		if strings.TrimSpace(pathValue) == "" {
			continue
		}

		entry := workspaceFolderEntry{path: pathValue}
		if name, ok := asMap["name"].(string); ok {
			entry.name = name
		}

		entries = append(entries, entry)
	}

	return entries
}

func addFolderEntry(entries []workspaceFolderEntry, workspaceDir, targetAbs string) []workspaceFolderEntry {
	for _, entry := range entries {
		if sameFolderTarget(workspaceDir, entry.path, targetAbs) {
			return entries
		}
	}

	entryPath := toWorkspacePath(workspaceDir, targetAbs)
	return append(entries, workspaceFolderEntry{path: entryPath})
}

func removeFolderEntry(entries []workspaceFolderEntry, workspaceDir, targetAbs string) []workspaceFolderEntry {
	filtered := make([]workspaceFolderEntry, 0, len(entries))
	for _, entry := range entries {
		if sameFolderTarget(workspaceDir, entry.path, targetAbs) {
			continue
		}
		filtered = append(filtered, entry)
	}
	return filtered
}

func entriesToAny(entries []workspaceFolderEntry) []any {
	items := make([]any, 0, len(entries))
	for _, entry := range entries {
		item := map[string]any{"path": entry.path}
		if entry.name != "" {
			item["name"] = entry.name
		}
		items = append(items, item)
	}
	return items
}

func sameFolderTarget(workspaceDir, configuredPath, targetAbs string) bool {
	resolved := configuredPath
	if !filepath.IsAbs(resolved) {
		resolved = filepath.Join(workspaceDir, resolved)
	}

	resolvedAbs, err := filepath.Abs(resolved)
	if err != nil {
		return false
	}

	return filepath.Clean(resolvedAbs) == filepath.Clean(targetAbs)
}

func toWorkspacePath(workspaceDir, targetAbs string) string {
	rel, err := filepath.Rel(workspaceDir, targetAbs)
	if err != nil {
		return targetAbs
	}

	return rel
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
	err := runCmdQuiet("", "git", "-C", src, "rev-parse", "--verify", "--quiet", ref+"^{commit}")
	return err == nil
}

func localBranchExists(src, branch string) bool {
	err := runCmdQuiet("", "git", "-C", src, "show-ref", "--verify", "--quiet", "refs/heads/"+branch)
	return err == nil
}

func copyLocalOnlyFiles(src, dst string) error {
	rs, err := exec.LookPath("rsync")
	if err == nil && rs != "" {
		cmd := fmt.Sprintf("git -C %q ls-files -z --others --ignored --exclude-standard | while IFS= read -r -d '' rel; do case \"$rel\" in .git|.git/*|.jj|.jj/*|node_modules|node_modules/*|bin|bin/*|obj|obj/*) ;; *) printf '%%s\\0' \"$rel\" ;; esac; done | rsync -a --from0 --files-from=- --ignore-missing-args %q/ %q/", src, src, dst)
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

		if _, err := os.Stat(srcPath); err != nil {
			if errors.Is(err, os.ErrNotExist) {
				continue
			}
			return err
		}

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
	rel = strings.TrimSpace(rel)
	rel = strings.TrimPrefix(rel, "./")
	rel = strings.TrimPrefix(rel, "/")

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
