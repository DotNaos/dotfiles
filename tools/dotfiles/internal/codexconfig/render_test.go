package codexconfig

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/pelletier/go-toml/v2"
)

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
}

func fixture(t *testing.T) Options {
	t.Helper()
	root := t.TempDir()
	opts := Options{Repo: filepath.Join(root, "repo"), Home: filepath.Join(root, "home"), Platform: "macos", Role: "personal", Mode: "interactive", Shell: "zsh"}
	if err := os.MkdirAll(opts.Home, 0700); err != nil {
		t.Fatal(err)
	}
	opts.RenderRoot = filepath.Join(opts.Home, ".local", "state", "dotfiles", "rendered")
	write(t, filepath.Join(opts.Repo, "context", "base", "codex", "config.toml"), "model = 'default-one'\nfeatures.stable = true\n")
	write(t, filepath.Join(opts.RenderRoot, ".codex", "config.toml"), "model = 'default-one'\nfeatures.stable = true\npersonality = 'friendly'\n[mcp_servers.native_read]\ncommand = 'ssh'\nargs = ['private-marker','stdio']\n")
	if err := os.MkdirAll(filepath.Join(opts.Home, ".codex"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(opts.RenderRoot, ".codex", "config.toml"), filepath.Join(opts.Home, ".codex", "config.toml")); err != nil {
		t.Fatal(err)
	}
	return opts
}

func load(t *testing.T, path string) map[string]any {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	value := map[string]any{}
	if err := toml.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	return value
}

func rendered(opts Options) string { return filepath.Join(opts.RenderRoot, ".codex", "config.toml") }
func privatePath(opts Options) string {
	return filepath.Join(opts.Home, ".config", "dotfiles", "codex", opts.Platform, opts.Role+".local.toml")
}
func metaPath(opts Options) string {
	return filepath.Join(opts.Home, ".config", "dotfiles", "codex", "last-render.json")
}

func saveTable(t *testing.T, path string, value map[string]any) {
	t.Helper()
	data, err := toml.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	write(t, path, string(data))
}

func TestMigrationRetainsNativeConnectionAndPreferencesThenRebuildIsStable(t *testing.T) {
	opts := fixture(t)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	value := load(t, rendered(opts))
	if value["personality"] != "friendly" || value["mcp_servers"].(map[string]any)["native_read"].(map[string]any)["command"] != "ssh" {
		t.Fatal("client settings lost")
	}
	before, err := os.ReadFile(rendered(opts))
	if err != nil {
		t.Fatal(err)
	}
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(rendered(opts))
	if !bytes.Equal(before, after) {
		t.Fatal("unchanged rebuild changed output")
	}
	meta, _ := os.ReadFile(metaPath(opts))
	if strings.Contains(string(meta), "private-marker") || strings.Contains(string(meta), "friendly") {
		t.Fatal("private values entered metadata")
	}
	for _, path := range []string{privatePath(opts), metaPath(opts), rendered(opts)} {
		info, err := os.Stat(path)
		if err != nil || info.Mode().Perm() != 0600 {
			t.Fatal("private file permissions")
		}
	}
	info, err := os.Stat(filepath.Dir(privatePath(opts)))
	if err != nil || info.Mode().Perm() != 0700 {
		t.Fatal("private directory permissions")
	}
}

func TestDefaultUpdatesAndExplicitPrivateEditsWinWhenLiveIsUnchanged(t *testing.T) {
	opts := fixture(t)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(opts.Repo, "context", "base", "codex", "config.toml"), "model = 'default-two'\nfeatures.stable = false\n")
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	if load(t, rendered(opts))["model"] != "default-two" {
		t.Fatal("old generated default pinned")
	}
	private := load(t, privatePath(opts))
	private["model"] = "explicit-private"
	saveTable(t, privatePath(opts), private)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	if load(t, rendered(opts))["model"] != "explicit-private" {
		t.Fatal("private edit lost")
	}
}

func TestClientEditsAndDeletionsPersistIncludingManagedDeletion(t *testing.T) {
	opts := fixture(t)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	live := load(t, rendered(opts))
	live["model"] = "client-choice"
	delete(live, "features")
	delete(live, "mcp_servers")
	saveTable(t, rendered(opts), live)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	value := load(t, rendered(opts))
	if value["model"] != "client-choice" {
		t.Fatal("client edit lost")
	}
	if _, present := value["features"]; present {
		t.Fatal("deleted managed preference returned")
	}
	if _, present := value["mcp_servers"]; present {
		t.Fatal("deleted native connection returned")
	}
	private := load(t, privatePath(opts))
	if _, present := private[privateKey]; !present {
		t.Fatal("deletions not recorded")
	}
	delete(private, privateKey)
	saveTable(t, privatePath(opts), private)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	if _, present := load(t, rendered(opts))["features"]; !present {
		t.Fatal("explicit tombstone removal did not restore defaults")
	}
}

func TestRoleIsolationNeverImportsPreviousContextLiveSecrets(t *testing.T) {
	opts := fixture(t)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	work := opts
	work.Role = "work"
	if err := Render(work); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(rendered(work))
	if strings.Contains(string(data), "native_read") || strings.Contains(string(data), "private-marker") {
		t.Fatal("personal connection crossed context boundary")
	}
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	if _, present := load(t, rendered(opts))["mcp_servers"]; !present {
		t.Fatal("personal settings not restored")
	}
	mode := opts
	mode.Mode = "noninteractive"
	write(t, filepath.Join(mode.Repo, "context", "mode", mode.Mode, "codex", "config.toml"), "mode_preference = 'new-default'\n")
	if err := Render(mode); err != nil {
		t.Fatal(err)
	}
	if load(t, rendered(mode))["mode_preference"] != "new-default" {
		t.Fatal("same-role mode defaults did not apply")
	}
}

func TestStructuralClientChangesDoNotCreateConflictingDeletionTombstones(t *testing.T) {
	for _, toTable := range []bool{true, false} {
		opts := fixture(t)
		live := load(t, rendered(opts))
		if toTable {
			live["custom"] = "scalar"
		} else {
			live["custom"] = map[string]any{"nested": "table"}
		}
		saveTable(t, rendered(opts), live)
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		live = load(t, rendered(opts))
		if toTable {
			live["custom"] = map[string]any{"nested": "table"}
		} else {
			live["custom"] = "scalar"
		}
		saveTable(t, rendered(opts), live)
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		value := load(t, rendered(opts))["custom"]
		if toTable {
			table, ok := value.(map[string]any)
			if !ok || table["nested"] != "table" {
				t.Fatal("new table was deleted")
			}
		} else if value != "scalar" {
			t.Fatal("new scalar was deleted")
		}
	}
}

func snapshot(t *testing.T, opts Options) map[string][]byte {
	t.Helper()
	result := map[string][]byte{}
	for _, path := range []string{rendered(opts), privatePath(opts), metaPath(opts)} {
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		result[path] = data
	}
	return result
}

func unchanged(t *testing.T, before map[string][]byte) {
	t.Helper()
	for path, wanted := range before {
		got, err := os.ReadFile(path)
		if err != nil || !bytes.Equal(got, wanted) {
			t.Fatal("failed preflight changed existing bytes")
		}
	}
}

func TestInvalidPrivateInputAndMetadataAreRedactedAndLeaveBytesUnchanged(t *testing.T) {
	for _, kind := range []string{"toml", "metadata", "metadata-trailing", "metadata-duplicate"} {
		opts := fixture(t)
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		switch kind {
		case "toml":
			write(t, privatePath(opts), "private-secret-marker = [broken\n")
		case "metadata":
			write(t, metaPath(opts), "{private-secret-marker")
		case "metadata-trailing":
			data, _ := os.ReadFile(metaPath(opts))
			write(t, metaPath(opts), string(data)+" {}")
		case "metadata-duplicate":
			data, _ := os.ReadFile(metaPath(opts))
			var value metadata
			_ = json.Unmarshal(data, &value)
			value.Leaves = append(value.Leaves, value.Leaves[0])
			data, _ = json.Marshal(value)
			write(t, metaPath(opts), string(data))
		}
		before := snapshot(t, opts)
		err := Render(opts)
		if err == nil || strings.Contains(err.Error(), "private-secret-marker") {
			t.Fatal("invalid/private diagnostic handling")
		}
		unchanged(t, before)
	}
}

func TestUnsafePathsModesAndNonbaseGuidanceFailBeforePublishing(t *testing.T) {
	for _, kind := range []string{"private-symlink", "private-mode", "private-dir-mode", "live-dir-symlink", "render-repo-symlink", "overlay-guidance", "public-conflict", "oversize"} {
		opts := fixture(t)
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		switch kind {
		case "private-symlink":
			original := privatePath(opts)
			copy := original + ".original"
			if err := os.Rename(original, copy); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(copy, original); err != nil {
				t.Fatal(err)
			}
		case "private-mode":
			if err := os.Chmod(privatePath(opts), 0644); err != nil {
				t.Fatal(err)
			}
		case "private-dir-mode":
			if err := os.Chmod(filepath.Dir(privatePath(opts)), 0755); err != nil {
				t.Fatal(err)
			}
		case "live-dir-symlink":
			source := filepath.Join(opts.Home, ".codex")
			target := source + ".original"
			if err := os.Rename(source, target); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(target, source); err != nil {
				t.Fatal(err)
			}
		case "render-repo-symlink":
			target := filepath.Join(opts.Repo, "private-output")
			if err := os.MkdirAll(target, 0700); err != nil {
				t.Fatal(err)
			}
			link := filepath.Join(opts.Home, "redirect")
			if err := os.Symlink(target, link); err != nil {
				t.Fatal(err)
			}
			opts.RenderRoot = link
		case "overlay-guidance":
			write(t, filepath.Join(opts.Repo, "context", "role", opts.Role, "codex", "AGENTS.md"), "disallowed")
		case "public-conflict":
			write(t, filepath.Join(opts.Repo, "context", "role", opts.Role, "codex", "config.toml"), "model = 'conflict'\n")
		case "oversize":
			write(t, privatePath(opts), strings.Repeat("x", maxFile+1))
		}
		if err := Render(opts); err == nil {
			t.Fatalf("accepted unsafe %s", kind)
		}
	}
}

func TestDryRunDoesNotCreatePrivateState(t *testing.T) {
	opts := fixture(t)
	opts.DryRun = true
	before, _ := os.ReadFile(rendered(opts))
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(rendered(opts))
	if !bytes.Equal(before, after) {
		t.Fatal("dry run changed config")
	}
	if _, err := os.Stat(filepath.Dir(privatePath(opts))); !os.IsNotExist(err) {
		t.Fatal("dry run created private state")
	}
}
