// Package codexconfig preserves client-owned Codex settings outside Git.
package codexconfig

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"path/filepath"
	"reflect"

	"github.com/pelletier/go-toml/v2"
)

type Options struct {
	Repo, Home, RenderRoot, Platform, Role, Mode, Shell string
	DryRun                                              bool
}

var errSafe = errors.New("Codex configuration could not be rendered safely")

const privateKey = "_dotfiles_codex"

type metadata struct {
	Version int        `json:"version"`
	Scope   []string   `json:"scope"`
	Leaves  []leafHash `json:"leaves"`
	Deleted [][]string `json:"deleted_paths,omitempty"`
}

type leafHash struct {
	Path []string `json:"path"`
	Hash string   `json:"hash"`
}

func Render(opts Options) error {
	if opts.DryRun {
		if err := render(opts); err != nil {
			return errSafe
		}
		return nil
	}
	preflight := opts
	preflight.DryRun = true
	if err := render(preflight); err != nil {
		return errSafe
	}
	p, err := preparePaths(opts)
	if err != nil {
		return errSafe
	}
	unlock, err := lockRender(p)
	if err != nil {
		return errSafe
	}
	defer unlock()
	if err := render(opts); err != nil {
		return errSafe
	}
	return nil
}

func render(opts Options) error {
	paths, err := preparePaths(opts)
	if err != nil {
		return err
	}
	defaults := map[string]any{}
	for _, fragment := range paths.fragments {
		data, err := readFile(fragment, false)
		if err != nil {
			return err
		}
		part, err := parseTOML(data.bytes)
		if err != nil {
			return err
		}
		if _, reserved := part[privateKey]; reserved {
			return errSafe
		}
		if err := mergeDisjoint(defaults, part); err != nil {
			return err
		}
	}
	privateState, err := readFile(paths.private, true)
	if err != nil {
		return err
	}
	private, err := parseTOML(privateState.bytes)
	if err != nil {
		return err
	}
	deleted, err := extractDeleted(private)
	if err != nil {
		return err
	}
	metaState, err := readFile(paths.meta, true)
	if err != nil {
		return err
	}
	var previous metadata
	if metaState.exists {
		decoder := json.NewDecoder(bytes.NewReader(metaState.bytes))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&previous); err != nil || previous.Version != 1 || len(previous.Scope) != 2 {
			return errSafe
		}
		var trailing any
		if decoder.Decode(&trailing) != io.EOF {
			return errSafe
		}
		if len(previous.Leaves) > 4096 || len(previous.Deleted) > 4096 {
			return errSafe
		}
		seen := map[string]bool{}
		descendants := map[string]bool{}
		for _, leaf := range previous.Leaves {
			if !validPath(leaf.Path) || !validHash(leaf.Hash) {
				return errSafe
			}
			if seen[pathKey(leaf.Path)] || descendants[pathKey(leaf.Path)] {
				return errSafe
			}
			for depth := 1; depth < len(leaf.Path); depth++ {
				key := pathKey(leaf.Path[:depth])
				if seen[key] {
					return errSafe
				}
				descendants[key] = true
			}
			seen[pathKey(leaf.Path)] = true
		}
		seen = map[string]bool{}
		for _, path := range previous.Deleted {
			if !validPath(path) || path[0] == privateKey || seen[pathKey(path)] {
				return errSafe
			}
			seen[pathKey(path)] = true
		}
	}
	liveState, err := readLive(paths)
	if err != nil {
		return err
	}
	live, err := parseTOML(liveState.bytes)
	if err != nil {
		return err
	}
	if _, reserved := live[privateKey]; reserved {
		return errSafe
	}
	scope := []string{opts.Platform, opts.Role}
	if liveState.exists && !metaState.exists {
		defaultLeaves := flatten(defaults)
		for key, leaf := range flatten(live) {
			defaultLeaf, present := defaultLeaves[key]
			if !present || !reflect.DeepEqual(leaf.value, defaultLeaf.value) {
				if _, explicit := lookup(private, leaf.path); !explicit {
					put(private, leaf.path, leaf.value)
				}
			}
		}
	} else if liveState.exists && reflect.DeepEqual(previous.Scope, scope) {
		current := flatten(live)
		known := map[string]string{}
		for _, leaf := range previous.Leaves {
			known[pathKey(leaf.Path)] = leaf.Hash
		}
		for key, leaf := range current {
			hash, err := valueHash(leaf.value)
			if err != nil {
				return err
			}
			if old, present := known[key]; !present || old != hash {
				put(private, leaf.path, leaf.value)
				deleted = removeConflictingDeletes(deleted, leaf.path)
			}
		}
		for _, leaf := range previous.Leaves {
			if _, present := current[pathKey(leaf.Path)]; !present {
				conflicts := false
				for _, now := range current {
					if prefix(leaf.Path, now.path) || prefix(now.path, leaf.Path) {
						conflicts = true
						break
					}
				}
				if conflicts {
					continue
				}
				path := firstMissing(live, leaf.Path)
				remove(private, path)
				deleted = appendUniquePath(deleted, path)
			}
		}
	}
	combined := merge(defaults, private)
	for _, path := range deleted {
		remove(combined, path)
	}
	result, err := toml.Marshal(combined)
	if err != nil || len(result) > maxFile {
		return errSafe
	}
	if _, err := parseTOML(result); err != nil {
		return err
	}
	leaves, err := hashes(combined)
	if err != nil {
		return err
	}
	metaBytes, err := json.Marshal(metadata{Version: 1, Scope: scope, Leaves: leaves, Deleted: deleted})
	if err != nil || len(metaBytes) > maxFile {
		return errSafe
	}
	if len(deleted) != 0 {
		private[privateKey] = map[string]any{"deleted_paths": deleted}
	}
	privateBytes, err := toml.Marshal(private)
	if err != nil || len(privateBytes) > maxFile {
		return errSafe
	}
	if opts.DryRun {
		return nil
	}
	// All inputs are parsed and validated before directories or files are created.
	return publish(paths, liveState, privateState, metaState, privateBytes, result, metaBytes)
}

func parseTOML(data []byte) (map[string]any, error) {
	result := map[string]any{}
	if err := toml.Unmarshal(data, &result); err != nil {
		return nil, errSafe
	}
	return result, nil
}

func extractDeleted(private map[string]any) ([][]string, error) {
	value, present := private[privateKey]
	if !present {
		return nil, nil
	}
	delete(private, privateKey)
	table, ok := value.(map[string]any)
	if !ok || len(table) != 1 {
		return nil, errSafe
	}
	items, ok := table["deleted_paths"].([]any)
	if !ok || len(items) > 4096 {
		return nil, errSafe
	}
	var paths [][]string
	for _, item := range items {
		parts, ok := item.([]any)
		if !ok {
			return nil, errSafe
		}
		path := make([]string, len(parts))
		for i, part := range parts {
			text, ok := part.(string)
			if !ok {
				return nil, errSafe
			}
			path[i] = text
		}
		if !validPath(path) || path[0] == privateKey {
			return nil, errSafe
		}
		paths = appendUniquePath(paths, path)
	}
	return paths, nil
}

func fragmentPaths(opts Options) []string {
	return []string{
		filepath.Join(opts.Repo, "context", "base", "codex", "config.toml"),
		filepath.Join(opts.Repo, "context", "platform", opts.Platform, "codex", "config.toml"),
		filepath.Join(opts.Repo, "context", "role", opts.Role, "codex", "config.toml"),
		filepath.Join(opts.Repo, "context", "mode", opts.Mode, "codex", "config.toml"),
		filepath.Join(opts.Repo, "context", "shell", opts.Shell, "codex", "config.toml"),
	}
}
