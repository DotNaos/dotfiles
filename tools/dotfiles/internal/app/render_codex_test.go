package app

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLiveFingerprintUsesStdoutWithoutSettings(t *testing.T) {
	repo, home := t.TempDir(), t.TempDir()
	dir := filepath.Join(home, ".codex")
	if err := os.Mkdir(dir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config.toml"), []byte("private_fixture = 'synthetic-value'\n"), 0600); err != nil {
		t.Fatal(err)
	}
	cmd := NewRootCommand()
	var out, stderr bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&stderr)
	cmd.SetArgs([]string{"--repo", repo, "render-codex", "--home", home,
		"--platform", "linux", "--role", "default", "--mode", "interactive",
		"--shell", "bash", "--fingerprint-live"})
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(out.String(), "regular:") || len(strings.TrimSpace(out.String())) != 72 {
		t.Fatalf("expected a regular-input fingerprint on stdout")
	}
	if stderr.Len() != 0 || strings.Contains(out.String(), "synthetic-value") {
		t.Fatal("fingerprint leaked a setting or used stderr")
	}
}
