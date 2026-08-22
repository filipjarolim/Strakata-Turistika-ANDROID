#!/usr/bin/env bash
set -euo pipefail

# Release helper for Strakatá Turistika
# - Bumps version in pubspec.yaml (patch by default; supports minor/major)
# - Uses Homebrew JDK 21 (Gradle 8 cannot run on system Java 25)
# - Builds signed Android App Bundle (.aab) and APK
# - Commits, tags, and pushes to origin
#
# Usage:
#   ./release.sh
#   ./release.sh "Commit message here"
#   ./release.sh --minor "Commit message here"
#   ./release.sh --major "Commit message here"
#   ./release.sh --skip-build "Commit message here"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
JDK_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "error: pubspec.yaml not found at $PUBSPEC" >&2
  exit 1
fi

BUMP="patch"
SKIP_BUILD=0
if [[ "${1:-}" == "--minor" || "${1:-}" == "-m" ]]; then
  BUMP="minor"; shift
elif [[ "${1:-}" == "--major" || "${1:-}" == "-M" ]]; then
  BUMP="major"; shift
elif [[ "${1:-}" == "--skip-build" ]]; then
  SKIP_BUILD=1; shift
fi

COMMIT_MSG="${1:-}"

if [[ -d "$JDK_HOME" ]]; then
  export JAVA_HOME="$JDK_HOME"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

echo "== Bumping version ($BUMP) in pubspec.yaml =="
current_line=$(grep -E '^version:' "$PUBSPEC" || true)
if [[ -z "$current_line" ]]; then
  echo "error: could not find version: line in pubspec.yaml" >&2
  exit 1
fi

version_str=$(echo "$current_line" | awk '{print $2}')
IFS='+.' read -r major minor patch build <<< "$(echo "$version_str" | sed 's/+/\./')"
major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}; build=${build:-0}

case "$BUMP" in
  major) major=$((major+1)); minor=0; patch=0 ;;
  minor) minor=$((minor+1)); patch=0 ;;
  patch) patch=$((patch+1)) ;;
esac
build=$((build+1))
new_version="${major}.${minor}.${patch}+${build}"
new_name="${major}.${minor}.${patch}"

sed -i '' -E "s/^version: .*/version: ${new_version}/" "$PUBSPEC"
echo "version: ${new_version}"

if [[ -z "$COMMIT_MSG" ]]; then
  COMMIT_MSG="Release v${new_name}: production build for Google Play"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "== Flutter clean & pub get =="
  (
    cd "$PROJECT_DIR"
    flutter clean
    flutter pub get
  )

  echo "== Building Android App Bundle (.aab) and APK =="
  (
    cd "$PROJECT_DIR"
    if [[ ! -f "$PROJECT_DIR/android/key.properties" ]]; then
      echo "error: android/key.properties missing. Create it for release signing." >&2
      echo "       Example:" >&2
      echo "       storePassword=YOUR_STORE_PASSWORD" >&2
      echo "       keyPassword=YOUR_KEY_PASSWORD" >&2
      echo "       keyAlias=upload" >&2
      echo "       storeFile=/absolute/path/to/upload-keystore.jks" >&2
      exit 1
    fi
    flutter build appbundle --release -t lib/main.dart
    flutter build apk --release -t lib/main.dart
  )
else
  echo "== Skipping Flutter build (--skip-build) =="
fi

echo "== Git commit, tag & push =="
(
  cd "$PROJECT_DIR"
  git rm -r --cached --ignore-unmatch android/build >/dev/null 2>&1 || true
  git add -A
  git restore --staged --worktree android/build 2>/dev/null || true
  git status --short
  if git diff --cached --quiet; then
    echo "warn: nothing to commit"
  else
    git commit -m "$COMMIT_MSG"
  fi
  git tag -a -f "v${new_name}" -m "$COMMIT_MSG"
  git push origin HEAD
  git push origin "v${new_name}"
)

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "Done. v${new_name} (${new_version})"
  echo "  AAB: $PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
  echo "  APK: $PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
else
  echo "Done. v${new_name} (${new_version}) pushed."
fi
