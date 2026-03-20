package app

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/spf13/cobra"
)

type repoStatus struct {
	Root          string
	Branch        string
	Upstream      string
	Ahead         int
	Behind        int
	Dirty         bool
	HasUpstream   bool
}

func NewRootCommand() *cobra.Command {
	opts := &rootOptions{
		repo: defaultRepoRoot(),
	}

	cmd := &cobra.Command{
		Use:   "dotfiles",
		Short: "Manage the dotfiles repository",
		Long:  "Inspect, update, and manage the local dotfiles checkout.",
	}

	cmd.PersistentFlags().StringVar(&opts.repo, "repo", opts.repo, "Path to the dotfiles repository")

	cmd.AddCommand(newPathCommand(opts))
	cmd.AddCommand(newStatusCommand(opts))
	cmd.AddCommand(newFetchCommand(opts))
	cmd.AddCommand(newUpdateCommand(opts))
	cmd.AddCommand(newCompletionCommand(cmd))
	cmd.SetHelpCommand(&cobra.Command{Hidden: true})

	return cmd
}

type rootOptions struct {
	repo string
}

func newPathCommand(opts *rootOptions) *cobra.Command {
	return &cobra.Command{
		Use:   "path",
		Short: "Print the dotfiles repository path",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			root, err := resolveRepoRoot(opts.repo)
			if err != nil {
				return err
			}

			fmt.Println(root)
			return nil
		},
	}
}

func newStatusCommand(opts *rootOptions) *cobra.Command {
	var porcelain bool

	cmd := &cobra.Command{
		Use:   "status",
		Short: "Show the current dotfiles repo status",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			root, err := resolveRepoRoot(opts.repo)
			if err != nil {
				return err
			}

			status, err := getRepoStatus(root)
			if err != nil {
				return err
			}

			if porcelain {
				fmt.Printf("root=%s\nbranch=%s\nupstream=%s\nahead=%d\nbehind=%d\ndirty=%t\n",
					status.Root, status.Branch, status.Upstream, status.Ahead, status.Behind, status.Dirty)
				return nil
			}

			fmt.Printf("repo: %s\nbranch: %s\n", status.Root, status.Branch)
			if status.HasUpstream {
				fmt.Printf("upstream: %s\nbehind: %d\nahead: %d\n", status.Upstream, status.Behind, status.Ahead)
			} else {
				fmt.Println("upstream: none")
			}

			if status.Dirty {
				fmt.Println("working tree: dirty")
			} else {
				fmt.Println("working tree: clean")
			}

			return nil
		},
	}

	cmd.Flags().BoolVar(&porcelain, "porcelain", false, "Print machine-readable output")
	return cmd
}

func newFetchCommand(opts *rootOptions) *cobra.Command {
	return &cobra.Command{
		Use:   "fetch",
		Short: "Fetch remote dotfiles updates",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			root, err := resolveRepoRoot(opts.repo)
			if err != nil {
				return err
			}

			return runInRepo(root, "git", "fetch", "--prune")
		},
	}
}

func newUpdateCommand(opts *rootOptions) *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "Fast-forward the local dotfiles checkout",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			root, err := resolveRepoRoot(opts.repo)
			if err != nil {
				return err
			}

			if err := runInRepo(root, "git", "fetch", "--prune"); err != nil {
				return err
			}

			return runInRepo(root, "git", "pull", "--ff-only")
		},
	}
}

func defaultRepoRoot() string {
	if value := os.Getenv("DOTFILES_ROOT"); value != "" {
		return value
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	return filepath.Join(home, "dotfiles")
}

func resolveRepoRoot(repo string) (string, error) {
	if repo == "" {
		return "", errors.New("dotfiles repo path is empty")
	}

	info, err := os.Stat(filepath.Join(repo, ".git"))
	if err != nil || !info.IsDir() && info.Mode()&os.ModeSymlink == 0 {
		return "", fmt.Errorf("not a dotfiles git repository: %s", repo)
	}

	return repo, nil
}

func getRepoStatus(root string) (*repoStatus, error) {
	branch, err := gitOutput(root, "rev-parse", "--abbrev-ref", "HEAD")
	if err != nil {
		return nil, err
	}

	status := &repoStatus{
		Root:   root,
		Branch: branch,
	}

	if upstream, err := gitOutput(root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"); err == nil {
		status.Upstream = upstream
		status.HasUpstream = true

		counts, err := gitOutput(root, "rev-list", "--left-right", "--count", "HEAD..."+upstream)
		if err == nil {
			parts := strings.Fields(counts)
			if len(parts) == 2 {
				status.Ahead, _ = strconv.Atoi(parts[0])
				status.Behind, _ = strconv.Atoi(parts[1])
			}
		}
	}

	dirty, err := gitOutput(root, "status", "--porcelain")
	if err != nil {
		return nil, err
	}
	status.Dirty = strings.TrimSpace(dirty) != ""

	return status, nil
}

func runInRepo(root string, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func gitOutput(root string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = root
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}
