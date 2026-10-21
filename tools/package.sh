#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
addon_version="$(tr -d '[:space:]' < VERSION)"
[[ "$addon_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || exit 1
go run ./cmd/fmt release validate-notes --version "$addon_version"
package_stage="$(mktemp -d)"
trap 'rm -rf "$package_stage"' EXIT
mkdir -p "$package_stage/ForeverManaTick" .release
for file in ForeverManaTick.lua README.md LICENSE ATTRIBUTION.md CHANGELOG.md RELEASE_NOTES.md; do
    cp "$file" "$package_stage/ForeverManaTick/"
done
sed "s/@project-version@/$addon_version/g" ForeverManaTick.toc > "$package_stage/ForeverManaTick/ForeverManaTick.toc"
package_path="$PWD/.release/ForeverManaTick-$addon_version.zip"
rm -f "$package_path"
(cd "$package_stage" && touch -t 198001010000 ForeverManaTick/* && \
    zip -X -q "$package_path" ForeverManaTick/*)
package_hash="$(shasum -a 256 "$package_path" | cut -d ' ' -f 1)"
notes_hash="$(shasum -a 256 RELEASE_NOTES.md | cut -d ' ' -f 1)"
package_commit="$(git rev-parse --verify HEAD 2>/dev/null || echo uncommitted)"
cat > "$package_path.manifest.txt" <<EOF
version=$addon_version
commit=$package_commit
flavor=WoW Forever beta
interface=$(sed -n 's/^## Interface: //p' ForeverManaTick.toc)
channel=release
file=$(basename "$package_path")
sha256=$package_hash
notes_sha256=$notes_hash
curseforge_project=not-configured
EOF
cat "$package_path.manifest.txt"
