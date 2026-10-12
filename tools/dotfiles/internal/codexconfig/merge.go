package codexconfig

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"sort"
	"strings"

	"github.com/pelletier/go-toml/v2"
)

type leaf struct {
	path  []string
	value any
}

func pathKey(path []string) string { value, _ := json.Marshal(path); return string(value) }

func validPath(path []string) bool {
	if len(path) == 0 || len(path) > 64 {
		return false
	}
	for _, key := range path {
		if key == "" {
			return false
		}
	}
	return true
}

func flatten(value map[string]any) map[string]leaf {
	result := map[string]leaf{}
	var visit func(map[string]any, []string)
	visit = func(table map[string]any, prefix []string) {
		for key, value := range table {
			path := append(append([]string{}, prefix...), key)
			if child, ok := value.(map[string]any); ok && len(child) != 0 {
				visit(child, path)
			} else {
				result[pathKey(path)] = leaf{path, value}
			}
		}
	}
	visit(value, nil)
	return result
}

func valueHash(value any) (string, error) {
	data, err := toml.Marshal(map[string]any{"value": value})
	if err != nil {
		return "", errSafe
	}
	hash := sha256.Sum256(data)
	return "sha256:" + hex.EncodeToString(hash[:]), nil
}

func validHash(value string) bool {
	if !strings.HasPrefix(value, "sha256:") || len(value) != 71 {
		return false
	}
	_, err := hex.DecodeString(strings.TrimPrefix(value, "sha256:"))
	return err == nil
}

func hashes(table map[string]any) ([]leafHash, error) {
	leaves := flatten(table)
	if len(leaves) > 4096 {
		return nil, errSafe
	}
	keys := make([]string, 0, len(leaves))
	for key := range leaves {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	result := make([]leafHash, 0, len(keys))
	for _, key := range keys {
		leaf := leaves[key]
		hash, err := valueHash(leaf.value)
		if err != nil {
			return nil, err
		}
		result = append(result, leafHash{Path: leaf.path, Hash: hash})
	}
	return result, nil
}

func mergeDisjoint(target, source map[string]any) error {
	for key, value := range source {
		old, present := target[key]
		if !present {
			target[key] = value
			continue
		}
		left, lok := old.(map[string]any)
		right, rok := value.(map[string]any)
		if !lok || !rok {
			return errSafe
		}
		if err := mergeDisjoint(left, right); err != nil {
			return err
		}
	}
	return nil
}

func merge(base, overlay map[string]any) map[string]any {
	result := map[string]any{}
	for key, value := range base {
		if child, ok := value.(map[string]any); ok {
			result[key] = merge(child, nil)
		} else {
			result[key] = value
		}
	}
	for key, value := range overlay {
		child, ok := value.(map[string]any)
		old, oldOK := result[key].(map[string]any)
		if ok && oldOK && len(child) != 0 {
			result[key] = merge(old, child)
		} else if ok {
			result[key] = merge(child, nil)
		} else {
			result[key] = value
		}
	}
	return result
}

func lookup(table map[string]any, path []string) (any, bool) {
	for _, key := range path[:len(path)-1] {
		child, ok := table[key].(map[string]any)
		if !ok {
			return nil, false
		}
		table = child
	}
	value, ok := table[path[len(path)-1]]
	return value, ok
}

func put(table map[string]any, path []string, value any) {
	for _, key := range path[:len(path)-1] {
		child, ok := table[key].(map[string]any)
		if !ok {
			child = map[string]any{}
			table[key] = child
		}
		table = child
	}
	table[path[len(path)-1]] = value
}

func remove(table map[string]any, path []string) {
	if len(path) == 1 {
		delete(table, path[0])
		return
	}
	child, ok := table[path[0]].(map[string]any)
	if !ok {
		return
	}
	remove(child, path[1:])
	if len(child) == 0 {
		delete(table, path[0])
	}
}

func prefix(left, right []string) bool {
	if len(left) > len(right) {
		return false
	}
	for i, key := range left {
		if key != right[i] {
			return false
		}
	}
	return true
}

func appendUniquePath(paths [][]string, path []string) [][]string {
	for _, other := range paths {
		if prefix(other, path) {
			return paths
		}
	}
	filtered := make([][]string, 0, len(paths)+1)
	for _, other := range paths {
		if !prefix(path, other) {
			filtered = append(filtered, other)
		}
	}
	return append(filtered, append([]string{}, path...))
}

func firstMissing(table map[string]any, path []string) []string {
	for i, key := range path {
		value, present := table[key]
		if !present {
			return path[:i+1]
		}
		child, ok := value.(map[string]any)
		if !ok {
			return path
		}
		table = child
	}
	return path
}

func removeConflictingDeletes(paths [][]string, path []string) [][]string {
	result := make([][]string, 0, len(paths))
	for _, other := range paths {
		if !prefix(other, path) && !prefix(path, other) {
			result = append(result, other)
		}
	}
	return result
}
