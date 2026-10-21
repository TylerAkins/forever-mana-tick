// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from Tyler Akins' forever-quest-markers repository.

// Package release validates versioned addon releases.
package release

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	versionPattern = regexp.MustCompile(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`)
	emailPattern   = regexp.MustCompile(`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`)
	headingPattern = regexp.MustCompile(`(?m)^## (\d+\.\d+\.\d+)(?:\s+[-—].*)?$`)
)

// Version is a stable addon version.
type Version struct {
	Major int
	Minor int
	Patch int
}

// ParseVersion reads a strict major.minor.patch version.
func ParseVersion(value string) (Version, error) {
	parts := versionPattern.FindStringSubmatch(strings.TrimSpace(value))
	if parts == nil {
		return Version{}, fmt.Errorf("invalid stable version: %q", value)
	}
	numbers := make([]int, 3)
	for index := range numbers {
		number, err := strconv.Atoi(parts[index+1])
		if err != nil {
			return Version{}, fmt.Errorf("invalid stable version: %q", value)
		}
		numbers[index] = number
	}
	return Version{Major: numbers[0], Minor: numbers[1], Patch: numbers[2]}, nil
}

// NextPatch returns the next patch version.
func (v Version) NextPatch() Version { return Version{v.Major, v.Minor, v.Patch + 1} }

// String renders the version.
func (v Version) String() string { return fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch) }

// PlanAutomatedRelease returns the release tag for a valid automated merge, or no release.
func PlanAutomatedRelease(previousText, currentText string, releaseContentChanged bool) (string, error) {
	if !releaseContentChanged {
		return "", nil
	}
	previous, err := ParseVersion(previousText)
	if err != nil {
		return "", err
	}
	current, err := ParseVersion(currentText)
	if err != nil {
		return "", err
	}
	expected := previous.NextPatch()
	if current != expected {
		return "", fmt.Errorf("release content changed, but VERSION must advance from %s to %s; found %s",
			previous, expected, current)
	}
	return "v" + current.String(), nil
}

// PlanTag reports whether an automated release tag is safe to create or reuse.
func PlanTag(existingSHA, targetSHA string) (string, error) {
	if targetSHA == "" {
		return "", errors.New("target tag commit SHA is required")
	}
	if existingSHA == "" {
		return "create", nil
	}
	if existingSHA != targetSHA {
		return "", fmt.Errorf("tag already points to %s, not target commit %s", existingSHA, targetSHA)
	}
	return "reuse", nil
}

// ValidateReleaseNotes requires current-version, single-release notes without email addresses.
func ValidateReleaseNotes(notes string, version Version) error {
	headings := headingPattern.FindAllStringSubmatch(notes, -1)
	if len(headings) != 1 || headings[0][1] != version.String() {
		return fmt.Errorf("RELEASE_NOTES.md must contain exactly one release heading for %s", version)
	}
	if emailPattern.MatchString(notes) {
		return errors.New("RELEASE_NOTES.md must not contain email addresses")
	}
	return nil
}

// ReleaseNotes returns validated notes containing only the current release entry.
func ReleaseNotes(entry string, version Version) (string, error) {
	notes := strings.TrimRight(entry, " \t\r\n") + "\n"
	if err := ValidateReleaseNotes(notes, version); err != nil {
		return "", err
	}
	return notes, nil
}

// ReplaceOrInsertChangelogEntry inserts a release entry, or refreshes the matching prepared entry.
func ReplaceOrInsertChangelogEntry(changelog string, version Version, entry string) (string, error) {
	headings := headingPattern.FindAllStringSubmatchIndex(changelog, -1)
	for index, heading := range headings {
		if changelog[heading[2]:heading[3]] != version.String() {
			continue
		}
		end := len(changelog)
		if index+1 < len(headings) {
			end = headings[index+1][0]
		}
		return changelog[:heading[0]] + strings.TrimRight(entry, " \t\r\n") + "\n\n" + changelog[end:], nil
	}
	firstRelease := regexp.MustCompile(`(?m)^## \d+\.\d+\.\d+`).FindStringIndex(changelog)
	if firstRelease == nil {
		return "", errors.New("CHANGELOG.md has no release heading")
	}
	return changelog[:firstRelease[0]] + entry + "\n" + changelog[firstRelease[0]:], nil
}

// Run executes a release subcommand.
func Run(args []string, stdout io.Writer) error {
	if len(args) == 0 {
		return errors.New("release requires validate, validate-notes, or validate-tag")
	}
	switch args[0] {
	case "validate":
		flags := flag.NewFlagSet("validate", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		previous := flags.String("previous-version", "", "previous stable version")
		current := flags.String("current-version", "", "current stable version")
		changed := flags.Bool("release-content-changed", false, "release content changed")
		root := flags.String("root", ".", "repository root")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		tag, err := PlanAutomatedRelease(*previous, *current, *changed)
		if err != nil || tag == "" {
			return err
		}
		version, err := ParseVersion(*current)
		if err != nil {
			return err
		}
		notes, err := os.ReadFile(filepath.Join(*root, "RELEASE_NOTES.md"))
		if err != nil {
			return err
		}
		if err := ValidateReleaseNotes(string(notes), version); err != nil {
			return err
		}
		_, err = fmt.Fprintln(stdout, tag)
		return err
	case "validate-notes":
		flags := flag.NewFlagSet("validate-notes", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		versionText := flags.String("version", "", "stable version")
		root := flags.String("root", ".", "repository root")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		version, err := ParseVersion(*versionText)
		if err != nil {
			return err
		}
		notes, err := os.ReadFile(filepath.Join(*root, "RELEASE_NOTES.md"))
		if err != nil {
			return err
		}
		return ValidateReleaseNotes(string(notes), version)
	case "validate-tag":
		flags := flag.NewFlagSet("validate-tag", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		existing := flags.String("existing-sha", "", "existing tag commit SHA")
		target := flags.String("target-sha", "", "target commit SHA")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		decision, err := PlanTag(*existing, *target)
		if err != nil {
			return err
		}
		_, err = fmt.Fprintln(stdout, decision)
		return err
	default:
		return fmt.Errorf("unknown release command %q", args[0])
	}
}
