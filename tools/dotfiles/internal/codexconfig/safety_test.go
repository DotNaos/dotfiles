package codexconfig

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestManagedSymlinkCanonicalAliasesReferToTheSameTarget(t *testing.T) {
	opts := fixture(t)
	alias := filepath.Join(filepath.Dir(opts.Home), "home-alias")
	if err := os.Symlink(opts.Home, alias); err != nil {
		t.Fatal(err)
	}
	live := filepath.Join(opts.Home, ".codex", "config.toml")
	if err := os.Remove(live); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(alias, ".local", "state", "dotfiles", "rendered", ".codex", "config.toml")
	if err := os.Symlink(target, live); err != nil {
		t.Fatal(err)
	}
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
}

func TestScopeTuplesDoNotCollideInPrivateFilenames(t *testing.T) {
	opts := fixture(t)
	first := opts
	first.Platform = "linux-work"
	first.Role = "default"
	second := opts
	second.Platform = "linux"
	second.Role = "work-default"
	if privatePath(first) == privatePath(second) {
		t.Fatal("scope filename collision")
	}
	write(t, privatePath(first), "scope_value = 'first-private'\n")
	write(t, privatePath(second), "scope_value = 'second-private'\n")
	if err := Render(first); err != nil {
		t.Fatal(err)
	}
	if load(t, rendered(first))["scope_value"] != "first-private" {
		t.Fatal("wrong first scope")
	}
	if err := Render(second); err != nil {
		t.Fatal(err)
	}
	if load(t, rendered(second))["scope_value"] != "second-private" {
		t.Fatal("private scope crossed")
	}
}

func TestExplicitEmptyTablesAndDeletedTableAncestorsRemainDeleted(t *testing.T) {
	for _, empty := range []bool{false, true} {
		opts := fixture(t)
		write(t, filepath.Join(opts.Repo, "context", "role", opts.Role, "codex", "config.toml"), "managed.one = 'public-one'\n")
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		live := load(t, rendered(opts))
		if empty {
			live["managed"] = map[string]any{}
		} else {
			delete(live, "managed")
		}
		saveTable(t, rendered(opts), live)
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		write(t, filepath.Join(opts.Repo, "context", "role", opts.Role, "codex", "config.toml"), "managed.one = 'public-one'\nmanaged.new = 'future-default'\n")
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		value, present := load(t, rendered(opts))["managed"]
		if empty {
			table, ok := value.(map[string]any)
			if !ok || len(table) != 0 {
				t.Fatal("empty client table repopulated")
			}
		} else if present {
			t.Fatal("deleted whole table regained a future default")
		}
	}
}

func TestLaterPublishFailureRollsBackEarlierAtomicRenames(t *testing.T) {
	for _, failure := range []int{2, 3} {
		opts := fixture(t)
		if err := Render(opts); err != nil {
			t.Fatal(err)
		}
		live := load(t, rendered(opts))
		live["personality"] = "new-client-value"
		saveTable(t, rendered(opts), live)
		before := snapshot(t, opts)
		oldRename := renameFile
		count := 0
		renameFile = func(source, target string) error {
			count++
			if count == failure {
				return errors.New("synthetic rename failure")
			}
			return os.Rename(source, target)
		}
		err := Render(opts)
		renameFile = oldRename
		if err == nil {
			t.Fatal("injected publication failure ignored")
		}
		unchanged(t, before)
	}
}

func TestSharedLockPreventsDifferentContextPublicationsFromInterleaving(t *testing.T) {
	opts := fixture(t)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	live := load(t, rendered(opts))
	live["personality"] = "changed-before-render"
	saveTable(t, rendered(opts), live)
	started := make(chan struct{})
	release := make(chan struct{})
	oldRename := renameFile
	count := 0
	renameFile = func(source, target string) error {
		count++
		if count == 1 {
			close(started)
			<-release
		}
		return os.Rename(source, target)
	}
	done := make(chan error, 1)
	go func() { done <- Render(opts) }()
	select {
	case <-started:
	case <-time.After(3 * time.Second):
		close(release)
		<-done
		renameFile = oldRename
		t.Fatal("first renderer did not start publication")
	}
	work := opts
	work.Role = "work"
	err := Render(work)
	close(release)
	firstErr := <-done
	renameFile = oldRename
	if firstErr != nil || err == nil {
		t.Fatal("concurrent context render was not rejected")
	}
	data, readErr := os.ReadFile(metaPath(opts))
	if readErr != nil {
		t.Fatal(readErr)
	}
	var meta metadata
	if err := json.Unmarshal(data, &meta); err != nil {
		t.Fatal(err)
	}
	if len(meta.Scope) != 2 || meta.Scope[1] != "personal" {
		t.Fatal("published context and metadata differed")
	}
	if _, err := os.Stat(privatePath(work)); !os.IsNotExist(err) {
		t.Fatal("rejected context created private settings")
	}
}

func TestChangedLiveConfigBeforePublicationAbortsWithoutReplacingClientEdit(t *testing.T) {
	opts := fixture(t)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	p, err := preparePaths(opts)
	if err != nil {
		t.Fatal(err)
	}
	live, err := readLive(p)
	if err != nil {
		t.Fatal(err)
	}
	private, err := readFile(p.private, true)
	if err != nil {
		t.Fatal(err)
	}
	meta, err := readFile(p.meta, true)
	if err != nil {
		t.Fatal(err)
	}
	write(t, rendered(opts), "model = 'new-client-value'\n")
	before := snapshot(t, opts)
	if err := publish(p, live, private, meta, []byte("model = 'private'\n"), []byte("model = 'wrong-output'\n"), []byte("{}")); err == nil {
		t.Fatal("concurrent live change was replaced")
	}
	unchanged(t, before)
}

func TestPendingPublicationBlocksCrossScopeImportAndPreservesAllBytes(t *testing.T) {
	opts := fixture(t)
	if err := Render(opts); err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(opts.Home, ".config", "dotfiles", "codex", ".publish-pending")
	write(t, marker, "pending\n")
	before := snapshot(t, opts)
	work := opts
	work.Role = "work"
	if err := Render(work); err == nil {
		t.Fatal("incomplete previous publication allowed context import")
	}
	unchanged(t, before)
	if _, err := os.Stat(privatePath(work)); !os.IsNotExist(err) {
		t.Fatal("pending publication created another context")
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatal("pending marker was silently cleared")
	}
}
