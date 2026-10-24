package app

import (
	"fmt"
	"os"
	"path/filepath"

	"dotfiles/internal/codexconfig"
	"github.com/spf13/cobra"
)

func newRenderCodexCommand(root *rootOptions) *cobra.Command {
	home, _ := os.UserHomeDir()
	opts := codexconfig.Options{Home: home}
	var fingerprint bool
	cmd := &cobra.Command{
		Use:          "render-codex",
		Short:        "Render Codex defaults while preserving private local settings",
		Args:         cobra.NoArgs,
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			opts.Repo = root.repo
			if opts.RenderRoot == "" {
				opts.RenderRoot = filepath.Join(opts.Home, ".local", "state", "dotfiles", "rendered")
			}
			if fingerprint {
				value, err := codexconfig.LiveFingerprint(opts)
				if err != nil {
					return err
				}
				fmt.Fprintln(cmd.OutOrStdout(), value)
				return nil
			}
			if err := codexconfig.Render(opts); err != nil {
				return err
			}
			if opts.DryRun {
				cmd.Println("Codex configuration validated; dry-run made no changes.")
			} else {
				cmd.Println("Codex configuration rendered; private local settings preserved.")
			}
			return nil
		},
	}
	cmd.Flags().StringVar(&opts.Home, "home", opts.Home, "Target home directory")
	cmd.Flags().StringVar(&opts.RenderRoot, "render-root", "", "Rendered output directory")
	cmd.Flags().StringVar(&opts.Platform, "platform", "", "Context platform")
	cmd.Flags().StringVar(&opts.Role, "role", "", "Context role")
	cmd.Flags().StringVar(&opts.Mode, "mode", "", "Context mode")
	cmd.Flags().StringVar(&opts.Shell, "shell", "", "Context shell")
	cmd.Flags().BoolVar(&opts.DryRun, "dry-run", false, "Validate without writing files")
	cmd.Flags().BoolVar(&fingerprint, "fingerprint-live", false, "Check the live input without printing settings")
	_ = cmd.Flags().MarkHidden("fingerprint-live")
	return cmd
}
