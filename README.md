# IDE - Integrated Development Environment

A comprehensive collection of tools, configuration files, and scripts for rapidly bootstrapping and deploying scalable web applications with standardized architecture.

## Repository Structure

```
ide/
│
├── config/                      # Configuration files
│   ├── eslint/                  # ESLint configuration for code quality enforcement
│   ├── firebase/                # Firebase project configuration templates
│   ├── prettier/                # Prettier formatting rules for consistent code style
│   └── typescript/              # TypeScript configuration with strict type checking
│       └── tsconfig.json        # Base TypeScript configuration file
│
├── hooks/                       # Git hooks for maintaining code quality
│   └── pre-commit               # Runs linting and formatting before commits
│
├── portal/                      # Portal application template
│   └── src/                     # Source code for the portal template
│       ├── components/          # Reusable React components
│       ├── lib/                 # Library code and service integrations
│       │   └── firebase.ts      # Firebase client configuration
│       ├── types/               # TypeScript type definitions
│       │   └── client.ts        # Client-related type definitions
│       └── utils/               # Utility functions
│
├── scripts/                     # Utility scripts for development workflow
│   ├── deploy-to-gcp.sh         # Deploys application to Google Cloud Platform
│   ├── init-firebase.sh         # Initializes Firebase project configuration
│   ├── init-git-yarn.sh         # Sets up Git repository and Yarn configuration
│   ├── init-master.sh           # Creates a new client portal project with full monorepo setup
│   ├── init-package.sh          # Initializes a package with dependencies and config
│   └── init-package.sh.backup   # Backup of package initialization script
│
├── dist/                        # Built distribution files
├── Dockerfile                   # Production-ready container definition
├── deploy-firebase.sh           # Script for Firebase deployment
├── firebase.json                # Firebase configuration for deployment
└── service-account.json         # Service account credentials for GCP
```

## Overview

This repository contains a production-ready development environment and project templates specifically designed for building client portal systems and other web applications. It includes optimized configurations for ESLint, Prettier, TypeScript, and Firebase, along with powerful scripts for project initialization, development workflow, and deployment.

## Directory Structure

- **`config/`** - Configuration files for development tools
  - **`eslint/`** - ESLint configuration for code quality enforcement
  - **`firebase/`** - Firebase project configuration templates
  - **`prettier/`** - Prettier formatting rules for consistent code style
  - **`typescript/`** - TypeScript configuration with strict type checking
    - **`tsconfig.json`** - Base TypeScript configuration
- **`hooks/`** - Git hooks for maintaining code quality
  - **`pre-commit`** - Runs linting and formatting before commits
- **`portal/`** - Portal application template with pre-configured components
  - **`src/`** - Source code for the portal template
    - **`components/`** - Reusable React components
    - **`lib/`** - Library code and service integrations
      - **`firebase.ts`** - Firebase client configuration
    - **`types/`** - TypeScript type definitions
      - **`client.ts`** - Client-related type definitions
    - **`utils/`** - Utility functions
- **`scripts/`** - Utility scripts for development workflow
  - **`init-master.sh`** - Creates a new client portal project with full monorepo setup
  - **`init-package.sh`** - Initializes a package with dependencies and config
  - **`init-git-yarn.sh`** - Sets up Git repository and Yarn configuration
  - **`init-firebase.sh`** - Initializes Firebase project configuration
  - **`deploy-to-gcp.sh`** - Deploys application to Google Cloud Platform
  - **`init-package.sh.backup`** - Backup of package initialization script
- **`Dockerfile`** - Production-ready container definition
- **`firebase.json`** - Firebase configuration for deployment
- **`deploy-firebase.sh`** - Script for Firebase deployment
- **`service-account.json`** - Service account credentials for GCP
- **`dist/`** - Built distribution files

## Usage Instructions

### Creating a New Project

```bash
~/ide/scripts/init-master.sh my-client-portal
```

This creates a complete monorepo with the following features:
- Frontend package using React/Vite with TypeScript
- Backend package with Node.js/Express API
- Shared package for common types and utilities
- Comprehensive Firebase configuration with security rules
- Deployment scripts for multiple environments
- Git hooks for code quality enforcement
- Package.json with predefined scripts and dependencies

### Project Structure Created

The initialization scripts create a scalable project with this structure:

```
my-client-portal/
├── packages/
│   ├── frontend/       # React/Vite frontend application
│   ├── backend/        # Node.js/Express backend API
│   └── shared/         # Shared types and utilities
├── config/             # Environment and configuration files
├── scripts/            # Deployment and utility scripts
├── firebase.json       # Firebase configuration
├── firestore.rules     # Firestore security rules
└── storage.rules       # Firebase Storage security rules
```

### Development Workflow

```bash
# Install dependencies
yarn install

# Start development servers
yarn dev

# Build all packages
yarn build

# Run linting
yarn lint

# Format code
yarn format

# Run tests
yarn test
```

### Deployment

```bash
# Deploy to Firebase
~/ide/deploy-firebase.sh project-directory

# Deploy to GCP
~/ide/scripts/deploy-to-gcp.sh project-directory
```

## Docker Container

Build and run the project in a Docker container with automatic dependency installation and build process:

```bash
# Build container image
docker build -t my-app .

# Run container with port mapping
docker run -p 8080:8080 my-app
```

## Architecture Features

- **Monorepo Architecture**: Using Yarn workspaces for efficient package management
- **TypeScript Integration**: Full type safety across all packages
- **Firebase Backend**: Authentication, Firestore database, and hosting
- **Security Rules**: Pre-configured security rules for Firebase services
- **Multi-tenancy**: Support for multiple client portals on the same infrastructure
- **CI/CD Ready**: Scripts for continuous integration and deployment
- **Docker Support**: Containerization for consistent deployments

## Capacity and Performance

- Designed to handle up to 5,000 total client portals
- Optimized for approximately 12 concurrent active portals
- Efficient database queries with proper indexing
- Cloudflare integration for edge caching