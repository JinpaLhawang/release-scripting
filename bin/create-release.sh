#!/bin/bash

function subtitle {
  echo ;
  echo "$(tput setaf 3;tput bold)$1$(tput sgr0)"
}
function keyValue {
  echo "$(tput setaf 3;tput bold)$1:$(tput sgr0) $2"
}
function warning {
  echo ;
  echo "$(tput setaf 2)$1$(tput sgr0)"
}
function error {
  echo ;
  echo "$(tput setaf 1;tput bold)Error: $1$(tput sgr0)"
}
function quit {
  echo ;
  echo "$(tput setaf 6;tput bold)$1$(tput sgr0)"
  echo ;
  exit
}

JQ_VERSION=$(jq --version)
if [[ $JQ_VERSION == "" ]]; then
  error "Requires package: jq"
  quit "Quitting."
fi

REQUIRED_JQ_VERSION=1.5
JQ_VERSION=${JQ_VERSION#jq-}

if (( $(echo "$JQ_VERSION < $REQUIRED_JQ_VERSION" | bc -l) )); then
  error "Package jq requires version: $REQUIRED_JQ_VERSION"
  quit "Quitting."
fi

echo ;
cd ~/Development/jambudvipa/release-scripting
pwd

subtitle "Checking git status..."
git status

subtitle "Updating develop..."
git checkout develop
git pull origin develop

subtitle "Updating master..."
git checkout master
git pull

subtitle "Merging develop into master..."
git merge develop

subtitle "Running tests..."
rm -rf node_modules/
npm install
npm test

subtitle "Getting project name from package.json..."
NAME=$(sed -e 's/^"//' -e 's/"$//' <<< $(cat package.json | jq '.name'))
keyValue "Project" $NAME

subtitle "Getting current version from git tag and package.json..."
PACKAGE_JSON_CURRENT_VERSION=$(sed -e 's/^"//' -e 's/"$//' <<< $(cat package.json | jq '.version'))
GIT_TAG_CURRENT_VERSION=$(git describe --abbrev=0 --tags)
if [[ $PACKAGE_JSON_CURRENT_VERSION == $GIT_TAG_CURRENT_VERSION ]]; then
  CURRENT_VERSION=$GIT_TAG_CURRENT_VERSION
  keyValue "Current Version" $CURRENT_VERSION
else
  error "The current version from the latest git tag and package.json are different. Please ensure they are equal."
  quit "Quitting."
fi

IFS=. PARTS=(${CURRENT_VERSION})
CURRENT_MAJOR=${PARTS[0]}
CURRENT_MINOR=${PARTS[1]}
CURRENT_MICRO=${PARTS[2]}

MAJOR_VERSION_BUMP="$(($CURRENT_MAJOR+1)).0.0"
MINOR_VERSION_BUMP="$CURRENT_MAJOR.$(($CURRENT_MINOR+1)).0"
MICRO_VERSION_BUMP="$CURRENT_MAJOR.$CURRENT_MINOR.$(($CURRENT_MICRO+1))"

MAJOR_SEMVER_OPTION="Major: $CURRENT_VERSION -> $MAJOR_VERSION_BUMP"
MINOR_SEMVER_OPTION="Minor: $CURRENT_VERSION -> $MINOR_VERSION_BUMP"
MICRO_SEMVER_OPTION="Micro: $CURRENT_VERSION -> $MICRO_VERSION_BUMP"

subtitle "Which semver version bump to use for release?"
SEMVER_OPTIONS=("$MAJOR_SEMVER_OPTION" "$MINOR_SEMVER_OPTION" "$MICRO_SEMVER_OPTION")
select SEMVER in "${SEMVER_OPTIONS[@]}"; do
  case "$SEMVER" in
    $MAJOR_SEMVER_OPTION)
      NEW_VERSION=$MAJOR_VERSION_BUMP;;
    $MINOR_SEMVER_OPTION)
      NEW_VERSION=$MINOR_VERSION_BUMP;;
    $MICRO_SEMVER_OPTION)
      NEW_VERSION=$MICRO_VERSION_BUMP;;
    *)
      error "Invalid option."
      quit "Quitting."
      ;;
  esac
  break;
done

subtitle "Updating package.json version: $SEMVER..."
cat package.json |
  jq "with_entries(
    if .key == \"version\"
    then . + {\"value\":\"$NEW_VERSION\"}
    else .
    end
  )" > package2.json
rm package.json
mv package2.json package.json

echo ;
git diff package.json

echo ;
read -r -p "Commit and tag release? [y/N] " RESPONSE
case $RESPONSE in
  [yY][eE][sS]|[yY])
    subtitle "Committing..."
    git add package.json
    git commit -m "Bumping version from $CURRENT_VERSION to $NEW_VERSION."
    git push

    subtitle "Tagging release..."
    git tag -a "$NEW_VERSION" -m "Release build $NEW_VERSION."
    git push --tags

    subtitle "Merging version bump back into develop..."
    git checkout develop
    git merge master
    git push
    quit "Completed."
    ;;
  *)
    subtitle "Rolling back changes..."
    git checkout package.json
    quit "Quitting."
    ;;
esac
