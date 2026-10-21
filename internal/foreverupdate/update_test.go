// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from Tyler Akins' forever-quest-markers repository.
package foreverupdate

import (
	"bytes"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

const versionsFeed = "Region!STRING:0|BuildId!DEC:4|VersionsName!String:0\n" +
	"## seqn = 1\n" +
	"us|69913|1.60.1.69913\n" +
	"eu|69913|1.60.1.69913\n"

func TestParseVersionsReadsTheRegionBuild(t *testing.T) {
	build, err := ParseVersions(versionsFeed, "us")
	if err != nil {
		t.Fatal(err)
	}
	if build.Version != "1.60.1.69913" || build.BuildID != 69913 || build.Interface != 16001 {
		t.Fatalf("unexpected build: %#v", build)
	}
}

func TestParseVersionsRejectsMalformedFeeds(t *testing.T) {
	if _, err := InterfaceFromVersion("1.60.1"); err == nil {
		t.Fatal("an incomplete game version was accepted")
	}
	if _, err := ParseVersions("Region!STRING:0|BuildId!DEC:4\n", "us"); err == nil {
		t.Fatal("a feed without the required columns was accepted")
	}
	for _, feed := range []string{
		"",
		"Region|BuildId|VersionsName\nus|not-a-number|1.60.1.1",
		"Region|BuildId|VersionsName\nus|1|invalid",
		"Region|BuildId|VersionsName\neu|1|1.60.1.1",
	} {
		if _, err := ParseVersions(feed, "us"); err == nil {
			t.Errorf("ParseVersions(%q) unexpectedly succeeded", feed)
		}
	}
}

func TestCurrentInterfacesReadsTheTOC(t *testing.T) {
	interfaces, err := CurrentInterfaces("## Interface: 16001, 16002\n## Version: @project-version@\n")
	if err != nil {
		t.Fatal(err)
	}
	if len(interfaces) != 2 || interfaces[0] != 16001 || interfaces[1] != 16002 {
		t.Fatalf("unexpected interfaces: %v", interfaces)
	}
	for _, toc := range []string{"## Version: 1\n", "## Interface: abc\n", "## Interface:\n"} {
		if _, err := CurrentInterfaces(toc); err == nil {
			t.Errorf("CurrentInterfaces(%q) unexpectedly succeeded", toc)
		}
	}
}

func TestPrepareUpdateWritesThePatchReleaseIdempotently(t *testing.T) {
	root := repositoryFixture(t, 16001)
	build := GameBuild{Version: "1.60.2.70123", BuildID: 70123, Interface: 16002}

	result, err := Prepare(root, build, "2026-09-23", false)
	if err != nil {
		t.Fatal(err)
	}
	if !result.Changed || result.AddonVersion != "0.1.22" {
		t.Fatalf("unexpected result: %#v", result)
	}
	toc := readFile(t, root, "ForeverManaTick.toc")
	if !strings.Contains(toc, "## Interface: 16002") {
		t.Fatalf("TOC was not updated: %s", toc)
	}
	if version := readFile(t, root, "VERSION"); version != "0.1.22\n" {
		t.Fatalf("VERSION = %q", version)
	}
	changelog := readFile(t, root, "CHANGELOG.md")
	if !strings.Contains(changelog, "## 0.1.22 - 2026-09-23") {
		t.Fatalf("changelog entry was not added: %s", changelog)
	}
	if !strings.Contains(changelog, "1.60.2.70123 (Interface 16002)") {
		t.Fatalf("changelog entry is missing the build: %s", changelog)
	}
	notes := readFile(t, root, "RELEASE_NOTES.md")
	if !strings.Contains(notes, "## 0.1.22 - 2026-09-23") ||
		!strings.Contains(notes, "1.60.2.70123 (Interface 16002)") {
		t.Fatalf("release notes were not prepared: %s", notes)
	}
	if strings.Count(notes, "## ") != 1 {
		t.Fatalf("release notes contain more than one entry: %s", notes)
	}

	second, err := Prepare(root, build, "", false)
	if err != nil {
		t.Fatal(err)
	}
	if second.Changed {
		t.Fatal("a prepared interface was prepared twice")
	}
}

func TestPrepareUpdateIgnoresSupportedInterfaces(t *testing.T) {
	root := repositoryFixture(t, 16001)
	before := releaseFiles(t, root)

	result, err := Prepare(root, GameBuild{Version: "1.60.1.79999", BuildID: 79999, Interface: 16001}, "", false)
	if err != nil {
		t.Fatal(err)
	}
	if result.Changed {
		t.Fatal("a supported interface reported a change")
	}
	if before != releaseFiles(t, root) {
		t.Fatal("a supported interface changed the release files")
	}
}

func TestPrepareUpdateDryRunLeavesFilesUnchanged(t *testing.T) {
	root := repositoryFixture(t, 16001)
	before := releaseFiles(t, root)

	result, err := Prepare(root, GameBuild{Version: "1.60.2.70123", BuildID: 70123, Interface: 16002}, "2026-09-23", true)
	if err != nil {
		t.Fatal(err)
	}
	if !result.Changed || result.AddonVersion != "0.1.22" {
		t.Fatalf("dry run result = %#v", result)
	}
	if before != releaseFiles(t, root) {
		t.Fatal("dry run changed the release files")
	}
}

func TestPrepareUpdateRefusesADowngrade(t *testing.T) {
	root := repositoryFixture(t, 16002)
	if _, err := Prepare(root, GameBuild{Version: "1.60.1.69913", BuildID: 69913, Interface: 16001}, "", false); err == nil {
		t.Fatal("an interface downgrade was accepted")
	}
}

func TestRunPrintsTheFeedURLAndParsedBuild(t *testing.T) {
	var output bytes.Buffer
	if err := Run([]string{"--print-url"}, &output); err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(output.String()) != VersionsURL {
		t.Fatalf("URL output %q", output.String())
	}
	feed := filepath.Join(t.TempDir(), "versions")
	if err := os.WriteFile(feed, []byte(versionsFeed), 0o644); err != nil {
		t.Fatal(err)
	}
	output.Reset()
	if err := Run([]string{"--versions-file", feed, "--print-game-build"}, &output); err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(output.String()) != "1.60.1.69913" {
		t.Fatalf("build output %q", output.String())
	}
}

func repositoryFixture(t *testing.T, interfaceID int) string {
	t.Helper()
	root := t.TempDir()
	writeFile(t, root, "ForeverManaTick.toc", "## Interface: "+strconv.Itoa(interfaceID)+"\n## Version: @project-version@\n")
	writeFile(t, root, "VERSION", "0.1.21\n")
	writeFile(t, root, "CHANGELOG.md", "# Changelog\n\nNotable changes.\n\n## 0.1.21 - 2026-09-19\n\n- Existing release.\n")
	writeFile(t, root, "RELEASE_NOTES.md", "## 0.1.21 - 2026-09-19\n\n- Existing release.\n")
	return root
}

func releaseFiles(t *testing.T, root string) string {
	t.Helper()
	contents := ""
	for _, name := range []string{"ForeverManaTick.toc", "VERSION", "CHANGELOG.md", "RELEASE_NOTES.md"} {
		contents += name + "\n" + readFile(t, root, name)
	}
	return contents
}

func writeFile(t *testing.T, root, name, contents string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(root, name), []byte(contents), 0o644); err != nil {
		t.Fatal(err)
	}
}

func readFile(t *testing.T, root, name string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(root, name))
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

