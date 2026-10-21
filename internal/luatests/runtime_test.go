// SPDX-License-Identifier: GPL-3.0-or-later

// Package luatests runs the Lua runtime fixture with LuaJIT.
package luatests

import (
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
)

func TestRuntimeFixtureRunsUnderLuaJIT(t *testing.T) {
	luajit, err := exec.LookPath("luajit")
	if err != nil {
		t.Skip("LuaJIT is not installed; run 'luajit tests/runtime.lua' to check the runtime fixture")
	}
	_, testFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("could not locate the test source")
	}
	root := filepath.Clean(filepath.Join(filepath.Dir(testFile), "..", ".."))
	command := exec.Command(luajit, filepath.Join("tests", "runtime.lua"))
	command.Dir = root
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("LuaJIT runtime fixture failed: %v\n%s", err, output)
	}
}
