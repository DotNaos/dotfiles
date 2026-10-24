package codexconfig

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

const maxFile = 4 * 1024 * 1024

type paths struct {
	home, privateDir, private, meta, target, live string
	fragments                                     []string
}

type fileState struct {
	exists bool
	bytes  []byte
	link   string
}

func preparePaths(opts Options) (paths, error) {
	for _, token := range []string{opts.Platform, opts.Role, opts.Mode, opts.Shell} {
		if token == "" {
			return paths{}, errSafe
		}
		for _, char := range token {
			if !(char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' || char >= '0' && char <= '9' || char == '-' || char == '_') {
				return paths{}, errSafe
			}
		}
	}
	var err error
	opts.Repo, err = canonical(opts.Repo)
	if err != nil {
		return paths{}, err
	}
	opts.Home, err = canonical(opts.Home)
	if err != nil {
		return paths{}, err
	}
	if opts.RenderRoot == "" {
		opts.RenderRoot = filepath.Join(opts.Home, ".local", "state", "dotfiles", "rendered")
	}
	opts.RenderRoot, err = canonical(opts.RenderRoot)
	if err != nil {
		return paths{}, err
	}
	privateDir := filepath.Join(opts.Home, ".config", "dotfiles", "codex")
	if _, err := os.Lstat(filepath.Join(privateDir, ".publish-pending")); err == nil || !os.IsNotExist(err) {
		return paths{}, errSafe
	}
	if inside(opts.Repo, privateDir) || inside(opts.Repo, opts.RenderRoot) {
		return paths{}, errSafe
	}
	p := paths{home: opts.Home, privateDir: privateDir,
		private: filepath.Join(privateDir, opts.Platform, opts.Role+".local.toml"),
		meta:    filepath.Join(privateDir, "last-render.json"),
		target:  filepath.Join(opts.RenderRoot, ".codex", "config.toml"),
		live:    filepath.Join(opts.Home, ".codex", "config.toml"), fragments: fragmentPaths(opts)}
	for _, path := range []string{p.private, p.meta, p.live} {
		if err := checkParents(path, p.home); err != nil {
			return paths{}, err
		}
	}
	if err := checkParentChain(p.target); err != nil {
		return paths{}, err
	}
	if info, err := os.Lstat(privateDir); err == nil {
		if !info.IsDir() || info.Mode().Perm() != 0700 || !owned(info) {
			return paths{}, errSafe
		}
	} else if !os.IsNotExist(err) {
		return paths{}, errSafe
	}
	if err := checkPrivateDirs(p); err != nil {
		return paths{}, err
	}
	for i, fragment := range p.fragments {
		if err := checkParents(fragment, opts.Repo); err != nil {
			return paths{}, err
		}
		if i > 0 {
			if _, err := os.Lstat(filepath.Join(filepath.Dir(fragment), "AGENTS.md")); err == nil || !os.IsNotExist(err) {
				return paths{}, errSafe
			}
		}
	}
	return p, nil
}

func canonical(path string) (string, error) {
	if path == "" {
		return "", errSafe
	}
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", errSafe
	}
	ancestor := absolute
	for {
		if _, err := os.Lstat(ancestor); err == nil {
			break
		} else if !os.IsNotExist(err) {
			return "", errSafe
		}
		parent := filepath.Dir(ancestor)
		if parent == ancestor {
			return "", errSafe
		}
		ancestor = parent
	}
	resolved, err := filepath.EvalSymlinks(ancestor)
	if err != nil {
		return "", errSafe
	}
	relative, err := filepath.Rel(ancestor, absolute)
	if err != nil {
		return "", errSafe
	}
	return filepath.Clean(filepath.Join(resolved, relative)), nil
}

func inside(root, path string) bool {
	rel, err := filepath.Rel(root, path)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

func checkParents(path, root string) error {
	if !inside(root, path) {
		return errSafe
	}
	relative, err := filepath.Rel(root, filepath.Dir(path))
	if err != nil {
		return errSafe
	}
	current := root
	for _, part := range strings.Split(relative, string(filepath.Separator)) {
		if part == "." {
			continue
		}
		current = filepath.Join(current, part)
		info, err := os.Lstat(current)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || !owned(info) || info.Mode().Perm()&0022 != 0 {
			return errSafe
		}
	}
	return nil
}

func checkParentChain(path string) error {
	current := filepath.Dir(path)
	for current != filepath.Dir(current) {
		info, err := os.Lstat(current)
		if err == nil && (!info.IsDir() || info.Mode()&os.ModeSymlink != 0) {
			return errSafe
		}
		if err != nil && !os.IsNotExist(err) {
			return errSafe
		}
		current = filepath.Dir(current)
	}
	return nil
}

func owned(info os.FileInfo) bool {
	stat, ok := info.Sys().(*syscall.Stat_t)
	return ok && stat.Uid == uint32(os.Getuid())
}

func checkPrivateDirs(p paths) error {
	for _, path := range []string{p.privateDir, filepath.Dir(p.private)} {
		info, err := os.Lstat(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil || !info.IsDir() || !owned(info) || info.Mode().Perm() != 0700 {
			return errSafe
		}
	}
	return nil
}

func lockRender(p paths) (func(), error) {
	if err := checkParents(filepath.Join(p.privateDir, ".render.lock"), p.home); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(p.privateDir, 0700); err != nil {
		return nil, errSafe
	}
	if err := checkPrivateDirs(p); err != nil {
		return nil, err
	}
	path := filepath.Join(p.privateDir, ".render.lock")
	if _, err := readFile(path, true); err != nil {
		return nil, err
	}
	fd, err := syscall.Open(path, syscall.O_WRONLY|syscall.O_CREAT|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return nil, errSafe
	}
	file := os.NewFile(uintptr(fd), "codex-render-lock")
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || !owned(info) || info.Mode().Perm() != 0600 {
		_ = file.Close()
		return nil, errSafe
	}
	if err := syscall.Flock(fd, syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = file.Close()
		return nil, errSafe
	}
	return func() { _ = syscall.Flock(fd, syscall.LOCK_UN); _ = file.Close() }, nil
}

func readFile(path string, private bool) (fileState, error) {
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return fileState{}, nil
	}
	if err != nil || !info.Mode().IsRegular() || info.Size() > maxFile {
		return fileState{}, errSafe
	}
	if private && (!owned(info) || info.Mode().Perm() != 0600) {
		return fileState{}, errSafe
	}
	fd, err := syscall.Open(path, syscall.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return fileState{}, errSafe
	}
	file := os.NewFile(uintptr(fd), "codex-private-input")
	defer file.Close()
	opened, err := file.Stat()
	if err != nil || !opened.Mode().IsRegular() || opened.Size() > maxFile || private && (!owned(opened) || opened.Mode().Perm() != 0600) {
		return fileState{}, errSafe
	}
	data, err := io.ReadAll(io.LimitReader(file, maxFile+1))
	if err != nil || len(data) > maxFile {
		return fileState{}, errSafe
	}
	return fileState{exists: true, bytes: data}, nil
}

func readLive(p paths) (fileState, error) {
	if err := checkParents(p.live, p.home); err != nil {
		return fileState{}, err
	}
	info, err := os.Lstat(p.live)
	if os.IsNotExist(err) {
		return fileState{}, nil
	}
	if err != nil {
		return fileState{}, errSafe
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return readFile(p.live, true)
	}
	link, err := os.Readlink(p.live)
	if err != nil {
		return fileState{}, errSafe
	}
	target := link
	if !filepath.IsAbs(target) {
		target = filepath.Join(filepath.Dir(p.live), target)
	}
	resolved, err := canonical(target)
	if err != nil || resolved != p.target {
		return fileState{}, errSafe
	}
	if err := checkParentChain(p.target); err != nil {
		return fileState{}, err
	}
	state, err := readFile(p.target, true)
	state.link = link
	return state, err
}

func sameState(left, right fileState) bool {
	return left.exists == right.exists && left.link == right.link && bytes.Equal(left.bytes, right.bytes)
}

type staged struct{ temporary, target string }

func stage(path string, data []byte) (staged, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return staged{}, errSafe
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".codex-render-*")
	if err != nil {
		return staged{}, errSafe
	}
	temporary := file.Name()
	ok := false
	defer func() {
		_ = file.Close()
		if !ok {
			_ = os.Remove(temporary)
		}
	}()
	if err := file.Chmod(0600); err != nil {
		return staged{}, errSafe
	}
	if _, err := file.Write(data); err != nil {
		return staged{}, errSafe
	}
	if err := file.Sync(); err != nil {
		return staged{}, errSafe
	}
	if err := file.Close(); err != nil {
		return staged{}, errSafe
	}
	ok = true
	return staged{temporary, path}, nil
}

func publish(p paths, live, private, meta fileState, privateBytes, result, metaBytes []byte) error {
	target, err := readFile(p.target, true)
	if err != nil {
		return err
	}
	var pending []staged
	originals := []fileState{private, target, meta}
	values := [][]byte{privateBytes, result, metaBytes}
	backups := make([]staged, 3)
	retain := map[string]bool{}
	defer func() {
		for _, item := range pending {
			_ = os.Remove(item.temporary)
		}
		for _, item := range backups {
			if item.temporary != "" && !retain[item.temporary] {
				_ = os.Remove(item.temporary)
			}
		}
	}()
	for i, path := range []string{p.private, p.target, p.meta} {
		data := values[i]
		item, err := stage(path, data)
		if err != nil {
			return err
		}
		pending = append(pending, item)
		if originals[i].exists {
			backup, err := stage(path, originals[i].bytes)
			if err != nil {
				return err
			}
			backups[i] = backup
		}
	}
	if err := checkParents(p.private, p.home); err != nil {
		return err
	}
	if err := checkPrivateDirs(p); err != nil {
		return err
	}
	if err := checkParentChain(p.target); err != nil {
		return err
	}
	currentLive, err := readLive(p)
	if err != nil || !sameState(live, currentLive) {
		return errSafe
	}
	for i, path := range []string{p.private, p.meta, p.target} {
		current, err := readFile(path, true)
		if err != nil || !sameState([]fileState{private, meta, target}[i], current) {
			return errSafe
		}
	}
	marker := filepath.Join(p.privateDir, ".publish-pending")
	if err := recordPending(marker); err != nil {
		return err
	}
	for i, item := range pending {
		if err := renameFile(item.temporary, item.target); err != nil {
			rolledBack := true
			for prior := i - 1; prior >= 0; prior-- {
				current, readErr := readFile(pending[prior].target, true)
				if readErr != nil || !sameState(current, fileState{exists: true, bytes: values[prior]}) {
					retain[backups[prior].temporary] = true
					rolledBack = false
					continue
				}
				if originals[prior].exists {
					if rollbackErr := renameFile(backups[prior].temporary, pending[prior].target); rollbackErr != nil {
						retain[backups[prior].temporary] = true
						rolledBack = false
					}
				} else {
					if err := os.Remove(pending[prior].target); err != nil {
						rolledBack = false
					}
				}
			}
			if rolledBack {
				for index, path := range []string{p.private, p.target, p.meta} {
					current, readErr := readFile(path, true)
					if readErr != nil || !sameState(current, originals[index]) {
						rolledBack = false
						retain[backups[index].temporary] = true
					}
				}
			}
			if rolledBack {
				_ = os.Remove(marker)
			}
			return errSafe
		}
	}
	if err := os.Remove(marker); err != nil {
		return errSafe
	}
	return nil
}

func recordPending(path string) error {
	fd, err := syscall.Open(path, syscall.O_WRONLY|syscall.O_CREAT|syscall.O_EXCL|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return errSafe
	}
	file := os.NewFile(uintptr(fd), "codex-publication-marker")
	ok := false
	defer func() {
		_ = file.Close()
		if !ok {
			_ = os.Remove(path)
		}
	}()
	if err := file.Chmod(0600); err != nil {
		return errSafe
	}
	if _, err := file.WriteString("pending\n"); err != nil {
		return errSafe
	}
	if err := file.Sync(); err != nil {
		return errSafe
	}
	if err := file.Close(); err != nil {
		return errSafe
	}
	ok = true
	return nil
}

// Replaced only by focused failure-injection tests; production uses os.Rename.
var renameFile = os.Rename
