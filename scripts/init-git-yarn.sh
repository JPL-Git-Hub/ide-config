#!/bin/bash

# Script to initialize a Yarn project with custom git hooks
# Usage: ./init-git-yarn.sh [project_directory]

set -e  # Exit on error

# Use provided directory or current directory
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Check if this is a git repository
if [ ! -d .git ]; then
  echo "Initializing git repository..."
  git init
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Install the pre-commit hook
echo "Installing pre-commit hook to block package-lock.json..."
cp ~/IDE/hooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit

# Initialize yarn if package.json doesn't exist
if [ ! -f package.json ]; then
  echo "Initializing yarn project..."
  yarn init -y
fi

# Add package-lock.json to .gitignore if it exists but doesn't already have it
if [ -f .gitignore ]; then
  if ! grep -q "package-lock.json" .gitignore; then
    echo "Adding package-lock.json to .gitignore..."
    echo -e "\n# Explicitly ignore package-lock.json files (using Yarn)" >> .gitignore
    echo "package-lock.json" >> .gitignore
  fi
else
  # Create a new .gitignore if it doesn't exist
  echo "Creating .gitignore..."
  cat > .gitignore << EOL
# Dependencies
node_modules
npm-debug.log*
package-lock.json  # Explicitly ignore package-lock.json

# Build output
dist
build
out

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# IDE and editors
.idea
.vscode
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db
EOL
fi

echo "✅ Project initialized with Yarn and git hooks!"
echo "The pre-commit hook will block any commits containing package-lock.json files."