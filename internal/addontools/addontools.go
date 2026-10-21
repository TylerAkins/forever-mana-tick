// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from Tyler Akins' forever-quest-markers repository.

// Package addontools builds and installs a clean local Forever Mana Tick addon.
package addontools

import (
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// AddonName is the installed addon folder name.
const AddonName = "ForeverManaTick"

// rootFiles are the repository files shipped by the addon package.
var rootFiles = []string{
	"ATTRIBUTION.md",
	"CHANGELOG.md",
	"ForeverManaTick.lua",
	"ForeverManaTick.toc",
	"LICENSE",
	"README.md",
	"RELEASE_NOTES.md",
}

// ProjectVersion returns a useful local version without requiring a tagged checkout.
func ProjectVersion(root string) string {
	command := exec.Command("git", "describe", "--tags", "--always", "--dirty")
	command.Dir = root
	output, err := command.Output()
	if err != nil || strings.TrimSpace(string(output)) == "" {
		return "local"
	}
	return strings.TrimSpace(string(output))
}

// IterFiles returns the files shipped by the release package metadata.
func IterFiles(root string) ([]string, error) {
	files := make([]string, 0, len(rootFiles))
	for _, name := range rootFiles {
		path := filepath.Join(root, name)
		if _, err := os.Stat(path); err != nil {
			return nil, err
		}
		files = append(files, path)
	}
	sort.Strings(files)
	return files, nil
}

// Compile replaces the local build with a clean installable addon tree.
func Compile(root, outputDir string, dryRun bool) ([]string, error) {
	files, err := IterFiles(root)
	if err != nil {
		return nil, err
	}
	outputs := make([]string, len(files))
	for index, source := range files {
		relative, err := filepath.Rel(root, source)
		if err != nil {
			return nil, err
		}
		outputs[index] = filepath.Join(outputDir, relative)
	}
	if dryRun {
		return outputs, nil
	}
	if err := os.RemoveAll(outputDir); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(outputDir, 0o755); err != nil {
		return nil, err
	}
	for index, source := range files {
		if err := copyFile(source, outputs[index]); err != nil {
			return nil, err
		}
	}
	tocPath := filepath.Join(outputDir, "ForeverManaTick.toc")
	toc, err := os.ReadFile(tocPath)
	if err != nil {
		return nil, err
	}
	version := strings.ReplaceAll(string(toc), "@project-version@", ProjectVersion(root))
	return outputs, os.WriteFile(tocPath, []byte(version), 0o644)
}

// InstallAddon copies the built addon into the client's AddOns folder.
func InstallAddon(buildDir, addonsDir string) (string, error) {
	source := filepath.Join(buildDir, "ForeverManaTick.toc")
	if info, err := os.Stat(source); err != nil || info.IsDir() {
		return "", fmt.Errorf("built addon TOC is missing: %s", source)
	}
	destination := filepath.Join(addonsDir, AddonName)
	if err := os.RemoveAll(destination); err != nil {
		return "", err
	}
	if err := os.MkdirAll(addonsDir, 0o755); err != nil {
		return "", err
	}
	if err := copyTree(buildDir, destination); err != nil {
		return "", err
	}
	return destination, nil
}

// DefaultAddonsDir resolves the default Forever beta AddOns directory on this Mac.
func DefaultAddonsDir() string {
	if configured := os.Getenv("WOW_FOREVER_ADDONS"); configured != "" {
		return expandUser(configured)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		home = ""
	}
	candidates := []string{
		"/Applications/World of Warcraft/_classic_beta_/Interface/AddOns",
		filepath.Join(home, "Library/Application Support/World of Warcraft/_classic_beta_/Interface/AddOns"),
	}
	for _, candidate := range candidates {
		if _, err := os.Stat(filepath.Dir(filepath.Dir(filepath.Dir(candidate)))); err == nil {
			return candidate
		}
	}
	return candidates[0]
}

func expandUser(path string) string {
	if !strings.HasPrefix(path, "~") {
		return path
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return path
	}
	if path == "~" {
		return home
	}
	return filepath.Join(home, strings.TrimPrefix(path, "~/"))
}

func copyFile(source, destination string) error {
	data, err := os.ReadFile(source)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	info, err := os.Stat(source)
	if err != nil {
		return err
	}
	if err := os.WriteFile(destination, data, info.Mode().Perm()); err != nil {
		return err
	}
	return os.Chtimes(destination, info.ModTime(), info.ModTime())
}

func copyTree(source, destination string) error {
	return filepath.Walk(source, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		relative, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := filepath.Join(destination, relative)
		if info.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported build entry: %s", path)
		}
		return copyFile(path, target)
	})
}

// RunCompile executes the compile-addon command.
func RunCompile(args []string, stdout io.Writer) error {
	flags := flag.NewFlagSet("compile-addon", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	root := flags.String("root", ".", "repository root")
	dryRun := flags.Bool("dry-run", false, "list the output files without deleting or copying anything")
	install := flags.Bool("install", false, "install the built addon into the client's AddOns directory")
	addonsDir := flags.String("addons-dir", "", "override the client's Interface/AddOns directory")
	if err := flags.Parse(args); err != nil {
		return err
	}
	output := filepath.Join(*root, ".compiled", AddonName)
	files, err := Compile(*root, output, *dryRun)
	if err != nil {
		return err
	}
	if *dryRun {
		for _, path := range files {
			relative, err := filepath.Rel(*root, path)
			if err != nil {
				return err
			}
			if _, err := fmt.Fprintln(stdout, relative); err != nil {
				return err
			}
		}
		return nil
	}
	if _, err := fmt.Fprintf(stdout, "Built %d files in %s\n", len(files), output); err != nil {
		return err
	}
	if !*install {
		return nil
	}
	destination, err := InstallAddon(output, resolveAddonsDir(*addonsDir))
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(stdout, "Installed %s in %s\n", AddonName, destination)
	return err
}

func resolveAddonsDir(configured string) string {
	if configured != "" {
		return expandUser(configured)
	}
	return DefaultAddonsDir()
}
