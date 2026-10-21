// SPDX-License-Identifier: GPL-3.0-or-later
package addontools

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func repositoryRoot(t *testing.T) string {
	t.Helper()
	root, err := filepath.Abs("../..")
	if err != nil {
		t.Fatal(err)
	}
	return root
}

func TestCompileProducesACleanInstallableTree(t *testing.T) {
	root := repositoryRoot(t)
	output := filepath.Join(t.TempDir(), "ForeverManaTick")
	if err := os.MkdirAll(output, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := filepath.Join(output, "stale.txt")
	if err := os.WriteFile(stale, []byte("remove me"), 0o644); err != nil {
		t.Fatal(err)
	}

	built, err := Compile(root, output, false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Fatalf("stale file remains in the build: %v", err)
	}
	for _, name := range []string{"ForeverManaTick.toc", "ForeverManaTick.lua", "README.md", "LICENSE", "ATTRIBUTION.md", "CHANGELOG.md", "RELEASE_NOTES.md"} {
		if !containsPath(built, filepath.Join(output, name)) {
			t.Errorf("build is missing %s", name)
		}
	}
	if _, err := os.Stat(filepath.Join(output, "VERSION")); !os.IsNotExist(err) {
		t.Error("VERSION must not ship in the addon package")
	}
	toc, err := os.ReadFile(filepath.Join(output, "ForeverManaTick.toc"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(toc), "@project-version@") {
		t.Fatal("project version token was not replaced")
	}
}

func TestCompileDryRunKeepsTheExistingOutput(t *testing.T) {
	root := repositoryRoot(t)
	output := filepath.Join(t.TempDir(), "ForeverManaTick")
	if err := os.MkdirAll(output, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := filepath.Join(output, "stale.txt")
	if err := os.WriteFile(stale, []byte("keep me"), 0o644); err != nil {
		t.Fatal(err)
	}

	listed, err := Compile(root, output, true)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(stale); err != nil {
		t.Fatalf("dry run removed an existing file: %v", err)
	}
	if !containsPath(listed, filepath.Join(output, "ForeverManaTick.toc")) {
		t.Fatal("dry run omitted the TOC")
	}
}

func TestEveryTOCEntryIsShipped(t *testing.T) {
	root := repositoryRoot(t)
	toc, err := os.ReadFile(filepath.Join(root, "ForeverManaTick.toc"))
	if err != nil {
		t.Fatal(err)
	}
	files, err := IterFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	shipped := map[string]bool{}
	for _, path := range files {
		relative, err := filepath.Rel(root, path)
		if err != nil {
			t.Fatal(err)
		}
		shipped[filepath.ToSlash(relative)] = true
	}
	for _, line := range strings.Split(string(toc), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		entry := strings.ReplaceAll(line, "\\", "/")
		if !shipped[entry] {
			t.Errorf("%s is in the TOC but not built", entry)
		}
	}
}

func TestInstallReplacesOnlyTheAddonDirectory(t *testing.T) {
	root := repositoryRoot(t)
	build := filepath.Join(t.TempDir(), "build", "ForeverManaTick")
	if _, err := Compile(root, build, false); err != nil {
		t.Fatal(err)
	}
	addons := filepath.Join(t.TempDir(), "AddOns")
	unrelated := filepath.Join(addons, "SomeOtherAddon", "keep.txt")
	if err := os.MkdirAll(filepath.Dir(unrelated), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(unrelated, []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}
	installed := filepath.Join(addons, "ForeverManaTick")
	if err := os.MkdirAll(installed, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := filepath.Join(installed, "stale.txt")
	if err := os.WriteFile(stale, []byte("remove"), 0o644); err != nil {
		t.Fatal(err)
	}

	destination, err := InstallAddon(build, addons)
	if err != nil {
		t.Fatal(err)
	}
	if destination != installed {
		t.Fatalf("install destination = %s", destination)
	}
	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Error("stale file remains in the installed addon")
	}
	if _, err := os.Stat(filepath.Join(installed, "ForeverManaTick.toc")); err != nil {
		t.Errorf("installed addon is missing its TOC: %v", err)
	}
	kept, err := os.ReadFile(unrelated)
	if err != nil || string(kept) != "keep" {
		t.Errorf("unrelated addon was modified: %q, %v", kept, err)
	}
}

func TestInstallRequiresABuiltAddon(t *testing.T) {
	if _, err := InstallAddon(filepath.Join(t.TempDir(), "missing"), t.TempDir()); err == nil {
		t.Fatal("a missing build was installed")
	}
}

func TestRunCompileInstallsIntoTheSelectedDirectory(t *testing.T) {
	root := repositoryRoot(t)
	workspace := t.TempDir()
	sources, err := IterFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	for _, source := range sources {
		relative, err := filepath.Rel(root, source)
		if err != nil {
			t.Fatal(err)
		}
		destination := filepath.Join(workspace, relative)
		if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
			t.Fatal(err)
		}
		data, err := os.ReadFile(source)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(destination, data, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	addons := filepath.Join(t.TempDir(), "client", "Interface", "AddOns")

	var output bytes.Buffer
	if err := RunCompile([]string{"--root", workspace, "--install", "--addons-dir", addons}, &output); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(addons, "ForeverManaTick", "ForeverManaTick.toc")); err != nil {
		t.Fatalf("the addon was not installed in the selected directory: %v", err)
	}
	if !strings.Contains(output.String(), "Installed ForeverManaTick") {
		t.Fatalf("install output = %q", output.String())
	}
}

func TestRunCompileDryRunListsTheShippedFiles(t *testing.T) {
	root := repositoryRoot(t)
	var output bytes.Buffer
	if err := RunCompile([]string{"--root", root, "--dry-run"}, &output); err != nil {
		t.Fatal(err)
	}
	listed := strings.Fields(output.String())
	prefix := ".compiled/ForeverManaTick/"
	if !containsString(listed, prefix+"ForeverManaTick.toc") || !containsString(listed, prefix+"ForeverManaTick.lua") {
		t.Fatalf("dry run output = %q", output.String())
	}
	if containsString(listed, prefix+"VERSION") {
		t.Fatalf("dry run listed a file that is not shipped: %q", output.String())
	}
}

func containsPath(paths []string, sought string) bool {
	for _, path := range paths {
		if path == sought {
			return true
		}
	}
	return false
}

func containsString(values []string, sought string) bool {
	for _, value := range values {
		if value == sought {
			return true
		}
	}
	return false
}
