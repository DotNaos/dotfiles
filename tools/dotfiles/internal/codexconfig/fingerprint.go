package codexconfig

import (
	"crypto/sha256"
	"encoding/hex"
)

// LiveFingerprint lets the linker detect a client replacing or editing its
// regular input between rendering and linking, without copying setting values.
func LiveFingerprint(opts Options) (string, error) {
	p, err := preparePaths(opts)
	if err != nil {
		return "", errSafe
	}
	state, err := readLive(p)
	if err != nil {
		return "", errSafe
	}
	if state.link != "" {
		return "managed-link", nil
	}
	if !state.exists {
		return "absent", nil
	}
	hash := sha256.Sum256(state.bytes)
	return "regular:" + hex.EncodeToString(hash[:]), nil
}
