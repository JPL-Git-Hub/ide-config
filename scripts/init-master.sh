#!/bin/bash
# Client Portal System Initialization Script
# Creates a monorepo architecture for a scalable client portal system
# Usage: ~/IDE/scripts/init-master.sh [project-name]

set -e # Exit on error

SCRIPT_DIR="$HOME/IDE/scripts"
PROJECT_NAME="${1:-client-portal-system}"
TARGET_DIR="$(pwd)/$PROJECT_NAME"

echo "🚀 Initializing Client Portal System: $PROJECT_NAME"
echo "📂 Target directory: $TARGET_DIR"

# Create project directory
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Initialize git repository
echo "🔄 Initializing git repository..."
git init
"$SCRIPT_DIR/init-git-yarn.sh" .

# Create monorepo structure
echo "📁 Creating monorepo directory structure..."
mkdir -p packages/{frontend,backend,shared}
mkdir -p config
mkdir -p docs

# Create root package.json for monorepo
echo "📦 Creating root package.json..."
cat > package.json << EOL
{
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "private": true,
  "workspaces": [
    "packages/*"
  ],
  "scripts": {
    "dev": "yarn workspaces foreach -pi run dev",
    "build": "yarn workspaces foreach -pi run build",
    "lint": "yarn workspaces foreach -pi run lint",
    "format": "yarn workspaces foreach -pi run format",
    "test": "yarn workspaces foreach -pi run test",
    "clean": "yarn workspaces foreach -pi run clean",
    "firebase:emulators": "firebase emulators:start",
    "firebase:deploy": "./scripts/deploy.sh",
    "generate:portal": "./scripts/generate-portal.sh"
  },
  "devDependencies": {
    "husky": "^8.0.3",
    "lint-staged": "^13.2.2",
    "typescript": "^5.0.4"
  },
  "packageManager": "yarn@4.0.0"
}
EOL

# Create workspaces
echo "🏗️ Setting up workspace packages..."

# Frontend package
mkdir -p "$TARGET_DIR/packages/frontend"
cd "$TARGET_DIR/packages/frontend"
"$SCRIPT_DIR/init-package.sh" "frontend" --monorepo

# Backend package
mkdir -p "$TARGET_DIR/packages/backend"
cd "$TARGET_DIR/packages/backend"
"$SCRIPT_DIR/init-package.sh" "backend" --monorepo

# Shared package
mkdir -p "$TARGET_DIR/packages/shared"
cd "$TARGET_DIR/packages/shared"
"$SCRIPT_DIR/init-package.sh" "full" --monorepo

# Return to project root
cd "$TARGET_DIR"

# Set up Firebase integration
echo "🔥 Setting up Firebase integration..."

# Create .firebaserc
cat > "$TARGET_DIR/.firebaserc" << EOL
{
  "projects": {
    "default": "$PROJECT_NAME"
  }
}
EOL

# Create firebase.json
cat > "$TARGET_DIR/firebase.json" << EOL
{
  "hosting": {
    "public": "packages/frontend/dist",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  },
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "hosting": {
      "port": 5000
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true
    }
  }
}
EOL

# Create Firestore rules
cat > "$TARGET_DIR/firestore.rules" << EOL
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Common functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuthenticated() && request.auth.token.admin == true;
    }
    
    function belongsToPortal(portalId) {
      return isAuthenticated() && request.auth.token.portalId == portalId;
    }
    
    // Portal configuration - admins can read all, portal users can read only their own
    match /portals/{portalId} {
      allow read: if isAdmin() || belongsToPortal(portalId);
      allow write: if isAdmin();
      
      // Nested collections within a portal
      match /users/{userId} {
        allow read: if isAdmin() || belongsToPortal(portalId);
        allow write: if isAdmin() || (belongsToPortal(portalId) && request.auth.uid == userId);
      }
      
      match /activities/{activityId} {
        allow read: if isAdmin() || belongsToPortal(portalId);
        allow create: if isAdmin() || belongsToPortal(portalId);
        allow update, delete: if isAdmin();
      }
    }
  }
}
EOL

# Create Firestore indexes
cat > "$TARGET_DIR/firestore.indexes.json" << EOL
{
  "indexes": [
    {
      "collectionGroup": "activities",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "portalId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "portalId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "role",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
EOL

# Create Storage rules
cat > "$TARGET_DIR/storage.rules" << EOL
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Common functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuthenticated() && request.auth.token.admin == true;
    }
    
    function belongsToPortal(portalId) {
      return isAuthenticated() && request.auth.token.portalId == portalId;
    }
    
    // Portal-specific storage
    match /portals/{portalId}/{allPaths=**} {
      allow read: if isAdmin() || belongsToPortal(portalId);
      allow write: if isAdmin() || belongsToPortal(portalId);
    }
    
    // Shared resources
    match /shared/{allPaths=**} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
  }
}
EOL

echo "✅ Firebase integration set up successfully!"

# Create deployment script
mkdir -p "$TARGET_DIR/scripts"

cat > "$TARGET_DIR/scripts/deploy.sh" << EOL
#!/bin/bash
# Master deployment script for the client portal system
set -e

# Build all packages
echo "🔨 Building all packages..."
yarn build

# Deploy Firebase services
echo "🔥 Deploying Firebase services..."
firebase deploy

# Deploy to Cloudflare
echo "☁️ Deploying to Cloudflare..."
# Add Cloudflare deployment commands here

echo "✅ Deployment complete!"
EOL

chmod +x "$TARGET_DIR/scripts/deploy.sh"

# Create portal generation script
cat > "$TARGET_DIR/scripts/generate-portal.sh" << EOL
#!/bin/bash
# Script to generate a new client portal
set -e

# Get portal details
[ -z "\$1" ] && { echo "Usage: ./scripts/generate-portal.sh <portal-name> <subdomain> <owner-email>"; exit 1; }

PORTAL_NAME="\$1"
SUBDOMAIN="\${2:-\$(echo \$PORTAL_NAME | tr '[:upper:]' '[:lower:]' | tr ' ' '-')}"
OWNER_EMAIL="\${3:-admin@\$SUBDOMAIN.example.com}"

echo "🔨 Generating new client portal: \$PORTAL_NAME (\$SUBDOMAIN)"

# Create Firestore entry for the portal
echo "📊 Creating Firestore entry..."
TEMP_FILE=\$(mktemp)
cat > "\$TEMP_FILE" << EOL
{
  "name": "\$PORTAL_NAME",
  "subdomain": "\$SUBDOMAIN",
  "createdAt": "\$(date +%s)",
  "status": "pending",
  "config": {
    "features": ["dashboard", "users", "settings"],
    "maxUsers": 50
  }
}
EOL
firebase database:set "/portals/\$SUBDOMAIN" "\$TEMP_FILE" --project \$PROJECT_NAME
rm "\$TEMP_FILE"

# Create owner account in Firebase Auth
echo "👤 Creating owner account..."
AUTH_TEMP_FILE=\$(mktemp)
cat > "\$AUTH_TEMP_FILE" << EOL
{"users":[{"localId":"\$SUBDOMAIN-admin", "email":"\$OWNER_EMAIL", "displayName":"Portal Admin", "customClaims":{"admin":true, "portalId":"\$SUBDOMAIN"}}]}
EOL
firebase auth:import --hash-algo=BCRYPT "\$AUTH_TEMP_FILE" --project \$PROJECT_NAME
rm "\$AUTH_TEMP_FILE"

echo "✅ Portal \$PORTAL_NAME (\$SUBDOMAIN) created successfully!"
echo "👤 Owner: \$OWNER_EMAIL"
echo "🌐 Portal URL: https://\$SUBDOMAIN.\${PROJECT_NAME}.com (after DNS setup)"
EOL

chmod +x "$TARGET_DIR/scripts/generate-portal.sh"

# Create root README.md
cat > "$TARGET_DIR/README.md" << EOL
# $PROJECT_NAME

A scalable client portal system built with a monorepo architecture.

## Overview

This system allows for the creation and management of up to 5,000 client portals, each with their own subdomain and authentication. It is designed as a minimalist MVP focused on essential functionality.

## Architecture

- **Frontend**: React/Vite for the portal UI
- **Backend**: Node.js/Express for API services
- **Shared**: Common types and utilities
- **Database**: Firestore
- **Authentication**: Firebase Auth
- **Hosting**: Firebase Hosting + Cloudflare CDN
- **Deployment**: GCP + Cloudflare

## Development

\`\`\`bash
# Install dependencies
yarn install

# Start development servers
yarn dev

# Build all packages
yarn build
\`\`\`

## Deployment

\`\`\`bash
# Deploy the entire system
yarn firebase:deploy
\`\`\`

## Creating a New Client Portal

\`\`\`bash
# Generate a new portal
yarn generate:portal "Client Name" "subdomain" "admin@example.com"
\`\`\`

## Project Structure

\`\`\`
$PROJECT_NAME/
├── packages/
│   ├── frontend/       # React/Vite frontend application
│   ├── backend/        # Node.js/Express backend API
│   └── shared/         # Shared types and utilities
├── config/             # Environment and configuration files
├── scripts/            # Deployment and utility scripts
├── firebase.json       # Firebase configuration
├── firestore.rules     # Firestore security rules
└── storage.rules       # Firebase Storage security rules
\`\`\`

## Capacity

- Maximum portals: 5,000
- Active concurrency: ~12 portals
- Default users per portal: 50 (configurable)
EOL

# Create architecture doc
mkdir -p "$TARGET_DIR/docs"

cat > "$TARGET_DIR/docs/architecture.md" << EOL
# Client Portal System Architecture

## System Overview

This client portal system is designed as a scalable, multi-tenant SaaS application that allows for the creation of isolated client portals, each with their own subdomain and authentication.

## Technical Architecture

### Frontend (React/Vite)
- Single-page application with dynamic portal theming
- Authentication with Firebase Auth
- Responsive design for all devices
- Component library for consistent UI
- Client-side routing with React Router
- State management with React Query + Context

### Backend (Node.js/Express)
- RESTful API endpoints
- Firebase Admin SDK integration
- Middleware for authentication and portal validation
- Rate limiting and security headers
- Serverless cloud functions for portal operations

### Data Storage (Firestore)
- NoSQL document database
- Collections:
  - portals: Portal configuration and metadata
  - users: User profiles and permissions
  - activities: Audit logs and user actions

### Authentication (Firebase Auth)
- Email/password authentication
- Custom claims for portal and role assignment
- Session management
- Password reset flow

### Hosting & Deployment
- Firebase Hosting for frontend assets
- Cloud Functions for backend logic
- Cloudflare for DNS and CDN
- Google Secret Manager for sensitive configuration

## Multi-tenancy Model

The system uses a hybrid multi-tenancy approach:
1. **Data isolation**: Each portal's data is segregated using Firestore security rules
2. **Subdomain routing**: Each portal gets a unique subdomain
3. **Shared infrastructure**: All portals share the same application codebase

## Security Considerations

- Firestore security rules enforce tenant isolation
- Firebase Auth custom claims control portal access
- HTTPS enforced throughout
- Content Security Policy headers
- Rate limiting to prevent abuse
- Audit logging for security events

## Scalability Considerations

- Designed to handle up to 5,000 total portals
- Optimized for ~12 concurrent active portals
- Leverages Firebase's auto-scaling capabilities
- Cloudflare caching for static assets
- Efficient database queries with proper indexing
EOL

echo "✅ Client Portal System initialization complete!"
echo "📋 Next steps:"
echo "  1. Navigate to $TARGET_DIR"
echo "  2. Install dependencies with 'yarn install'"
echo "  3. Start development with 'yarn dev'"
echo "  4. Review architecture docs in the 'docs' directory"
echo ""
echo "🎉 Happy coding!"