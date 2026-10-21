// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from Tyler Akins' forever-quest-markers repository.
package release

import (
	"strings"
	"testing"
)

func TestPlanAutomatedRelease(t *testing.T) {
	tests := []struct {
		name, previous, current string
		changed                 bool
		want                    string
		wantErr                 bool
	}{
		{"next patch", "0.1.0", "0.1.1", true, "v0.1.1", false},
		{"same version", "0.1.0", "0.1.0", true, "", true},
		{"skipped patch", "0.1.0", "0.1.2", true, "", true},
		{"minor advance", "0.1.0", "0.2.0", true, "", true},
		{"no release content change", "0.1.0", "0.1.0", false, "", false},
		{"invalid previous version", "0.1", "0.1.1", true, "", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := PlanAutomatedRelease(tt.previous, tt.current, tt.changed)
			if (err != nil) != tt.wantErr || got != tt.want {
				t.Fatalf("PlanAutomatedRelease(%q, %q, %v) = %q, %v; want %q, error=%v",
					tt.previous, tt.current, tt.changed, got, err, tt.want, tt.wantErr)
			}
		})
	}
}

func TestPlanTag(t *testing.T) {
	tests := []struct {
		name, existing, target string
		want                   string
		wantErr                bool
	}{
		{"missing tag", "", "aaa", "create", false},
		{"matching tag", "aaa", "aaa", "reuse", false},
		{"moved tag", "bbb", "aaa", "", true},
		{"missing target", "", "", "", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := PlanTag(tt.existing, tt.target)
			if (err != nil) != tt.wantErr || got != tt.want {
				t.Fatalf("PlanTag(%q, %q) = %q, %v; want %q, error=%v",
					tt.existing, tt.target, got, err, tt.want, tt.wantErr)
			}
		})
	}
}

func TestParseVersion(t *testing.T) {
	version, err := ParseVersion("0.1.21\n")
	if err != nil {
		t.Fatal(err)
	}
	if version.String() != "0.1.21" {
		t.Fatalf("ParseVersion() = %s", version)
	}
	if next := version.NextPatch(); next.String() != "0.1.22" {
		t.Fatalf("NextPatch() = %s", next)
	}
	for _, invalid := range []string{"v0.1.21", "0.1", "01.2.3", "0.1.21.4", ""} {
		if _, err := ParseVersion(invalid); err == nil {
			t.Fatalf("ParseVersion(%q) accepted an invalid version", invalid)
		}
	}
}

func TestValidateReleaseNotes(t *testing.T) {
	version, err := ParseVersion("0.1.0")
	if err != nil {
		t.Fatal(err)
	}
	if err := ValidateReleaseNotes("## 0.1.0 - 2026-10-10\n\n- Mana display.\n", version); err != nil {
		t.Fatal(err)
	}
	for _, notes := range []string{
		"## 0.1.1\n",
		"## 0.1.0\n\n## 0.0.1\n",
		"## 0.1.0\nuser@example.com",
		"",
	} {
		if err := ValidateReleaseNotes(notes, version); err == nil {
			t.Fatalf("ValidateReleaseNotes accepted %q", notes)
		}
	}
}

func TestReleaseNotesTrimsAndValidates(t *testing.T) {
	version := Version{Major: 0, Minor: 1, Patch: 0}
	notes, err := ReleaseNotes("## 0.1.0 - 2026-10-10\n\n- Mana display.\n\n", version)
	if err != nil {
		t.Fatal(err)
	}
	if notes != "## 0.1.0 - 2026-10-10\n\n- Mana display.\n" {
		t.Fatalf("ReleaseNotes() = %q", notes)
	}
	if _, err := ReleaseNotes("## 0.2.0\n", version); err == nil {
		t.Fatal("ReleaseNotes accepted notes for another version")
	}
}

func TestReplaceOrInsertChangelogEntry(t *testing.T) {
	version := Version{Major: 0, Minor: 1, Patch: 22}
	changelog := "# Changelog\n\n## 0.1.21 - 2026-09-19\n\n- Existing release.\n"
	entry := "## 0.1.22 - 2026-09-23\n\n- Update WoW Forever compatibility.\n"
	updated, err := ReplaceOrInsertChangelogEntry(changelog, version, entry)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(updated, "## 0.1.22 - 2026-09-23") {
		t.Fatalf("changelog entry was not inserted: %s", updated)
	}
	if strings.Index(updated, "## 0.1.22") > strings.Index(updated, "## 0.1.21") {
		t.Fatalf("new entry was not placed first: %s", updated)
	}
	if strings.Count(updated, "## 0.1.22") != 1 {
		t.Fatalf("changelog entry was duplicated: %s", updated)
	}

	refreshed, err := ReplaceOrInsertChangelogEntry(updated, version, entry)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(refreshed, "## 0.1.22") != 1 {
		t.Fatalf("changelog entry was duplicated: %s", refreshed)
	}

	if _, err := ReplaceOrInsertChangelogEntry("# Changelog\n\nNo releases yet.\n", version, entry); err == nil {
		t.Fatal("a changelog without release headings was accepted")
	}
}
