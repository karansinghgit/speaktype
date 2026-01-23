#!/bin/bash

# SpeakType Release Script
# This script helps you create a new release with proper versioning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 SpeakType Release Creator${NC}"
echo ""

# Get current version from git tags
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "📌 Current version: ${GREEN}${CURRENT_VERSION}${NC}"
echo ""

# Ask for new version
read -p "Enter new version (e.g., v1.0.0): " NEW_VERSION

# Validate version format
if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid version format. Please use format: v1.0.0${NC}"
    exit 1
fi

# Check if version already exists
if git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
    echo -e "${RED}❌ Version $NEW_VERSION already exists!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📝 Release Summary:${NC}"
echo -e "   Previous: ${CURRENT_VERSION}"
echo -e "   New:      ${GREEN}${NEW_VERSION}${NC}"
echo ""

# Ask for confirmation
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Release cancelled${NC}"
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  You have uncommitted changes:${NC}"
    git status -s
    echo ""
    read -p "Commit these changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter commit message: " COMMIT_MSG
        git add .
        git commit -m "$COMMIT_MSG"
        echo -e "${GREEN}✅ Changes committed${NC}"
    else
        echo -e "${RED}❌ Please commit or stash your changes first${NC}"
        exit 1
    fi
fi

# Ensure we're on main/master
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
    echo -e "${YELLOW}⚠️  You're on branch: ${CURRENT_BRANCH}${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Release cancelled${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}🏗️  Building release artifacts...${NC}"
make clean
make release

if [ ! -f "dist/SpeakType.dmg" ]; then
    echo -e "${RED}❌ Build failed - DMG not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Build successful!${NC}"
echo ""
echo -e "${BLUE}📦 Release artifacts:${NC}"
ls -lh dist/

echo ""
echo -e "${BLUE}🏷️  Creating git tag...${NC}"
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"
echo -e "${GREEN}✅ Tag created: $NEW_VERSION${NC}"

echo ""
echo -e "${YELLOW}Ready to push!${NC}"
echo ""
echo "The following will be pushed:"
echo "  1. Branch: $CURRENT_BRANCH"
echo "  2. Tag: $NEW_VERSION"
echo ""
read -p "Push to GitHub? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}⬆️  Pushing to GitHub...${NC}"
    git push origin "$CURRENT_BRANCH"
    git push origin "$NEW_VERSION"
    
    echo ""
    echo -e "${GREEN}✅ Release $NEW_VERSION pushed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next steps:${NC}"
    echo "  1. GitHub Actions is building your release (takes ~5 minutes)"
    echo "  2. Check: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
    echo "  3. Release will be available at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/releases/tag/$NEW_VERSION"
    echo ""
    echo -e "${GREEN}🎉 All done!${NC}"
else
    echo ""
    echo -e "${YELLOW}⏸️  Not pushed yet.${NC}"
    echo ""
    echo "To push manually later:"
    echo "  git push origin $CURRENT_BRANCH"
    echo "  git push origin $NEW_VERSION"
    echo ""
    echo "To delete the tag if you change your mind:"
    echo "  git tag -d $NEW_VERSION"
fi
