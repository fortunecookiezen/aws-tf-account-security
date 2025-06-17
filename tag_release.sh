#!/usr/bin/env bash
# This script tags the current commit with a version number and pushes the tag to the remote repository.
set -e
# Check if a version number is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <version>"
  exit 1
fi
VERSION="$1"
# Check if the version number is valid
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version number must be in the format X.Y.Z (e.g., 1.0.0)"
  exit 1
fi
# Ensure the tag does not already exist
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Error: Tag v$VERSION already exists. Please use a different version number."
  exit 1
fi
# Create a tag with the provided version number
git tag -a "v$VERSION" -m "Release version $VERSION"
# Push the tag to the remote repository
git push origin "v$VERSION"
# Output the success message
echo "Successfully tagged and pushed version $VERSION"
# Optionally, you can also push the changes to the main branch
# git push origin main
# Uncomment the line above if you want to push changes to the main branch as well
# Note: Ensure you have the necessary permissions to push tags to the remote repository
# Ensure you are on the main branch before tagging
git checkout main
# Ensure the local repository is up to date
git pull origin main
# Ensure the local repository is clean
if ! git diff-index --quiet HEAD --; then
  echo "Error: Your working directory is not clean. Please commit or stash your changes before tagging."
  exit 1
fi
