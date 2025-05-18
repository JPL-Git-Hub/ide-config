#!/bin/bash

# Firebase Project Initialization Script for solo developers
# Creates production-ready Firebase setup with secure configurations
# Usage: ~/IDE/scripts/init-firebase.sh [project-name]

set -e # Exit on error

PROJECT_NAME="${1:-$(basename $(pwd))}"
REPO_ROOT="$(pwd)"
GCP_PROJECT_ID="${PROJECT_NAME//-/}"  # Remove hyphens for GCP ID
DEFAULT_REGION="us-central1"
FIRESTORE_LOCATION="us-central"

echo "🔥 Initializing Firebase for project: $PROJECT_NAME"
echo "📂 Setting up in: $REPO_ROOT"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
  echo "❌ Firebase CLI not found. Please install it first with: npm install -g firebase-tools"
  exit 1
fi

# Check if logged into Firebase
firebase login:list &> /dev/null || {
  echo "🔑 Please log in to Firebase CLI:"
  firebase login
}

# Initialize Firebase project
echo "🚀 Creating Firebase project..."
firebase projects:create $GCP_PROJECT_ID --display-name "$PROJECT_NAME" --no-interactive || {
  echo "⚠️  Project may already exist. Continuing with existing project."
  firebase use $GCP_PROJECT_ID --add
}

# Set up Firebase project configuration files
echo "📝 Creating Firebase configuration files..."

# Create firebase.json
cat > $REPO_ROOT/firebase.json << EOL
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  },
  "hosting": {
    "public": "dist",
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
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      },
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      },
      {
        "source": "404.html",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=3600"
          }
        ]
      }
    ]
  },
  "functions": {
    "source": "functions",
    "predeploy": [
      "npm --prefix functions run lint",
      "npm --prefix functions run build"
    ],
    "runtime": "nodejs18"
  },
  "emulators": {
    "auth": {
      "port": 9099
    },
    "functions": {
      "port": 5001
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
      "enabled": true,
      "port": 4000
    }
  }
}
EOL

# Create .firebaserc
cat > $REPO_ROOT/.firebaserc << EOL
{
  "projects": {
    "default": "$GCP_PROJECT_ID"
  }
}
EOL

# Create Firestore security rules
echo "🔒 Creating Firestore security rules..."
cat > $REPO_ROOT/firestore.rules << EOL
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Common functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    function hasValidFields(requiredFields, optionalFields) {
      let allFields = requiredFields.concat(optionalFields);
      return request.resource.data.keys().hasOnly(allFields) &&
             request.resource.data.keys().hasAll(requiredFields);
    }

    // Users collection
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.auth.uid == userId;
      allow update: if isOwner(userId);
      allow delete: if isOwner(userId);
      
      // User's private data
      match /private/{document=**} {
        allow read, write: if isOwner(userId);
      }
    }
    
    // Public data that any signed-in user can read but only owners can modify
    match /data/{docId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.createdBy == request.auth.uid;
      allow update, delete: if isSignedIn() && resource.data.createdBy == request.auth.uid;
    }
    
    // Default deny
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
EOL

# Create Firestore indexes
cat > $REPO_ROOT/firestore.indexes.json << EOL
{
  "indexes": [
    {
      "collectionGroup": "data",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "createdBy", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
EOL

# Create Storage security rules
echo "🔒 Creating Storage security rules..."
cat > $REPO_ROOT/storage.rules << EOL
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Common functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    function isValidContentType(contentTypes) {
      return request.resource.contentType.matches(contentTypes);
    }
    
    function isValidSize(maxSizeMB) {
      return request.resource.size <= maxSizeMB * 1024 * 1024;
    }

    // User files
    match /users/{userId}/{allPaths=**} {
      allow read: if isSignedIn();
      allow write: if isOwner(userId) 
                   && isValidContentType('image/.*|application/pdf|text/.*') 
                   && isValidSize(10);
    }
    
    // Public files
    match /public/{allPaths=**} {
      allow read: if isSignedIn();
      allow write: if isSignedIn()
                   && isValidContentType('image/.*|application/pdf|text/.*') 
                   && isValidSize(10);
    }
    
    // Default deny
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
EOL

# Create Firebase Services Directory
mkdir -p $REPO_ROOT/src/services/firebase

# Create Firebase configuration wrapper for frontend
echo "📦 Creating Firebase service wrappers..."
mkdir -p $REPO_ROOT/src/services/firebase
mkdir -p $REPO_ROOT/src/services/secrets

# Create Firebase Config Service
cat > $REPO_ROOT/src/services/firebase/config.ts << EOL
import { initializeApp, FirebaseOptions, FirebaseApp } from 'firebase/app';
import { getFirestore, Firestore } from 'firebase/firestore';
import { getAuth, Auth } from 'firebase/auth';
import { getStorage, FirebaseStorage } from 'firebase/storage';
import { getFunctions, Functions } from 'firebase/functions';
import { getAnalytics, Analytics } from 'firebase/analytics';
import { getSecretConfig } from '../secrets/manager';

// Firebase configuration singleton
class FirebaseConfig {
  private static instance: FirebaseConfig;
  private app: FirebaseApp | null = null;
  private db: Firestore | null = null;
  private auth: Auth | null = null;
  private storage: FirebaseStorage | null = null;
  private functions: Functions | null = null;
  private analytics: Analytics | null = null;

  private constructor() {
    // Private constructor for singleton
  }

  public static getInstance(): FirebaseConfig {
    if (!FirebaseConfig.instance) {
      FirebaseConfig.instance = new FirebaseConfig();
    }
    return FirebaseConfig.instance;
  }

  // Initialize Firebase with configuration from Secret Manager
  public async initialize(): Promise<void> {
    try {
      if (this.app) return; // Already initialized

      const config = await getSecretConfig();
      this.app = initializeApp(config);
      console.log('Firebase initialized successfully');

      // Pre-initialize services
      this.db = getFirestore(this.app);
      this.auth = getAuth(this.app);
      this.storage = getStorage(this.app);
      this.functions = getFunctions(this.app);
      
      // Only initialize analytics in browser environment
      if (typeof window !== 'undefined') {
        this.analytics = getAnalytics(this.app);
      }
    } catch (error) {
      console.error('Failed to initialize Firebase:', error);
      throw error;
    }
  }

  // Service getters
  public getApp(): FirebaseApp {
    if (!this.app) throw new Error('Firebase not initialized');
    return this.app;
  }

  public getFirestore(): Firestore {
    if (!this.db) {
      if (!this.app) throw new Error('Firebase not initialized');
      this.db = getFirestore(this.app);
    }
    return this.db;
  }

  public getAuth(): Auth {
    if (!this.auth) {
      if (!this.app) throw new Error('Firebase not initialized');
      this.auth = getAuth(this.app);
    }
    return this.auth;
  }

  public getStorage(): FirebaseStorage {
    if (!this.storage) {
      if (!this.app) throw new Error('Firebase not initialized');
      this.storage = getStorage(this.app);
    }
    return this.storage;
  }

  public getFunctions(): Functions {
    if (!this.functions) {
      if (!this.app) throw new Error('Firebase not initialized');
      this.functions = getFunctions(this.app);
    }
    return this.functions;
  }

  public getAnalytics(): Analytics | null {
    // Only available in browser environment
    if (typeof window === 'undefined') return null;
    
    if (!this.analytics && this.app) {
      this.analytics = getAnalytics(this.app);
    }
    return this.analytics;
  }
}

export default FirebaseConfig.getInstance();
EOL

# Create Auth Service
cat > $REPO_ROOT/src/services/firebase/auth.ts << EOL
import { 
  createUserWithEmailAndPassword, 
  signInWithEmailAndPassword,
  signOut,
  sendPasswordResetEmail,
  updateProfile,
  User,
  UserCredential
} from 'firebase/auth';
import firebaseConfig from './config';

export class AuthService {
  // Initialize auth service
  public async initialize(): Promise<void> {
    await firebaseConfig.initialize();
  }

  // Get current user
  public getCurrentUser(): User | null {
    const auth = firebaseConfig.getAuth();
    return auth.currentUser;
  }

  // Sign up with email/password
  public async signUp(email: string, password: string, displayName?: string): Promise<UserCredential> {
    const auth = firebaseConfig.getAuth();
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    
    // Set display name if provided
    if (displayName && userCredential.user) {
      await updateProfile(userCredential.user, { displayName });
    }
    
    return userCredential;
  }

  // Sign in with email/password
  public async signIn(email: string, password: string): Promise<UserCredential> {
    const auth = firebaseConfig.getAuth();
    return signInWithEmailAndPassword(auth, email, password);
  }

  // Sign out
  public async signOut(): Promise<void> {
    const auth = firebaseConfig.getAuth();
    return signOut(auth);
  }

  // Reset password
  public async resetPassword(email: string): Promise<void> {
    const auth = firebaseConfig.getAuth();
    return sendPasswordResetEmail(auth, email);
  }

  // Listen for auth state changes
  public onAuthStateChanged(callback: (user: User | null) => void): () => void {
    const auth = firebaseConfig.getAuth();
    return auth.onAuthStateChanged(callback);
  }
}

export default new AuthService();
EOL

# Create Firestore Service
cat > $REPO_ROOT/src/services/firebase/firestore.ts << EOL
import { 
  collection, 
  doc,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  DocumentReference,
  QueryConstraint,
  DocumentData,
  DocumentSnapshot,
  QuerySnapshot
} from 'firebase/firestore';
import firebaseConfig from './config';

export class FirestoreService {
  // Initialize Firestore service
  public async initialize(): Promise<void> {
    await firebaseConfig.initialize();
  }

  // Create or overwrite a document
  public async setDocument<T extends DocumentData>(
    collectionPath: string, 
    docId: string, 
    data: T
  ): Promise<void> {
    const db = firebaseConfig.getFirestore();
    const docRef = doc(db, collectionPath, docId);
    await setDoc(docRef, {
      ...data,
      updatedAt: new Date(),
      createdAt: data.createdAt || new Date()
    });
  }

  // Get a document by ID
  public async getDocument<T = DocumentData>(
    collectionPath: string, 
    docId: string
  ): Promise<T | null> {
    const db = firebaseConfig.getFirestore();
    const docRef = doc(db, collectionPath, docId);
    const docSnap = await getDoc(docRef);
    
    if (docSnap.exists()) {
      return docSnap.data() as T;
    }
    
    return null;
  }

  // Update a document (partial update)
  public async updateDocument<T extends DocumentData>(
    collectionPath: string, 
    docId: string, 
    data: Partial<T>
  ): Promise<void> {
    const db = firebaseConfig.getFirestore();
    const docRef = doc(db, collectionPath, docId);
    await updateDoc(docRef, {
      ...data,
      updatedAt: new Date()
    });
  }

  // Delete a document
  public async deleteDocument(
    collectionPath: string, 
    docId: string
  ): Promise<void> {
    const db = firebaseConfig.getFirestore();
    const docRef = doc(db, collectionPath, docId);
    await deleteDoc(docRef);
  }

  // Query documents
  public async queryDocuments<T = DocumentData>(
    collectionPath: string,
    constraints: QueryConstraint[] = []
  ): Promise<T[]> {
    const db = firebaseConfig.getFirestore();
    const collectionRef = collection(db, collectionPath);
    const q = query(collectionRef, ...constraints);
    const querySnapshot = await getDocs(q);
    
    return querySnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })) as T[];
  }

  // Get document reference
  public getDocumentReference(
    collectionPath: string, 
    docId: string
  ): DocumentReference {
    const db = firebaseConfig.getFirestore();
    return doc(db, collectionPath, docId);
  }
}

export default new FirestoreService();
EOL

# Create Storage Service
cat > $REPO_ROOT/src/services/firebase/storage.ts << EOL
import { 
  ref,
  uploadBytes,
  getDownloadURL,
  deleteObject,
  listAll,
  StorageReference
} from 'firebase/storage';
import firebaseConfig from './config';

export class StorageService {
  // Initialize Storage service
  public async initialize(): Promise<void> {
    await firebaseConfig.initialize();
  }

  // Upload file
  public async uploadFile(
    path: string, 
    file: File | Blob | Uint8Array | ArrayBuffer,
    metadata?: any
  ): Promise<string> {
    const storage = firebaseConfig.getStorage();
    const storageRef = ref(storage, path);
    
    await uploadBytes(storageRef, file, metadata);
    return getDownloadURL(storageRef);
  }

  // Get download URL
  public async getFileUrl(path: string): Promise<string> {
    const storage = firebaseConfig.getStorage();
    const storageRef = ref(storage, path);
    return getDownloadURL(storageRef);
  }

  // Delete file
  public async deleteFile(path: string): Promise<void> {
    const storage = firebaseConfig.getStorage();
    const storageRef = ref(storage, path);
    await deleteObject(storageRef);
  }

  // List all files in a directory
  public async listFiles(path: string): Promise<StorageReference[]> {
    const storage = firebaseConfig.getStorage();
    const storageRef = ref(storage, path);
    const result = await listAll(storageRef);
    return result.items;
  }

  // Generate user file path
  public getUserFilePath(userId: string, filename: string): string {
    return `users/${userId}/${filename}`;
  }

  // Generate public file path
  public getPublicFilePath(filename: string): string {
    return `public/${filename}`;
  }
}

export default new StorageService();
EOL

# Create Functions Service
cat > $REPO_ROOT/src/services/firebase/functions.ts << EOL
import { httpsCallable, HttpsCallableResult } from 'firebase/functions';
import firebaseConfig from './config';

export class FunctionsService {
  // Initialize Functions service
  public async initialize(): Promise<void> {
    await firebaseConfig.initialize();
  }

  // Call a cloud function
  public async callFunction<T = any, R = any>(
    name: string, 
    data?: T
  ): Promise<HttpsCallableResult<R>> {
    const functions = firebaseConfig.getFunctions();
    const functionRef = httpsCallable<T, R>(functions, name);
    return functionRef(data);
  }
}

export default new FunctionsService();
EOL

# Create Analytics Service
cat > $REPO_ROOT/src/services/firebase/analytics.ts << EOL
import { logEvent, setUserId, setUserProperties } from 'firebase/analytics';
import firebaseConfig from './config';

export class AnalyticsService {
  // Initialize Analytics service
  public async initialize(): Promise<void> {
    await firebaseConfig.initialize();
  }

  // Log an event
  public logEvent(eventName: string, eventParams?: Record<string, any>): void {
    const analytics = firebaseConfig.getAnalytics();
    if (analytics) {
      logEvent(analytics, eventName, eventParams);
    }
  }

  // Set user ID
  public setUserId(userId: string | null): void {
    const analytics = firebaseConfig.getAnalytics();
    if (analytics && userId) {
      setUserId(analytics, userId);
    }
  }

  // Set user properties
  public setUserProperties(properties: Record<string, any>): void {
    const analytics = firebaseConfig.getAnalytics();
    if (analytics) {
      setUserProperties(analytics, properties);
    }
  }
}

export default new AnalyticsService();
EOL

# Create Secret Manager service
cat > $REPO_ROOT/src/services/secrets/manager.ts << EOL
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

export interface FirebaseConfig {
  apiKey: string;
  authDomain: string;
  projectId: string;
  storageBucket: string;
  messagingSenderId: string;
  appId: string;
  measurementId?: string;
}

// Secret names
const FIREBASE_CONFIG_SECRET = 'firebase-config';

// Secret Manager client (singleton)
let secretManagerClient: SecretManagerServiceClient | null = null;

// Get Secret Manager client with auth
const getSecretManagerClient = (): SecretManagerServiceClient => {
  if (!secretManagerClient) {
    secretManagerClient = new SecretManagerServiceClient();
  }
  return secretManagerClient;
};

// Get Firebase config from Secret Manager
export const getSecretConfig = async (): Promise<FirebaseConfig> => {
  try {
    // For local development with emulators
    if (process.env.FIREBASE_USE_EMULATORS === 'true') {
      return {
        apiKey: 'fake-api-key',
        authDomain: 'localhost',
        projectId: '${GCP_PROJECT_ID}',
        storageBucket: 'localhost',
        messagingSenderId: '000000000000',
        appId: '1:000000000000:web:0000000000000000000000'
      };
    }

    // In production, get from Secret Manager
    const client = getSecretManagerClient();
    const projectId = process.env.GOOGLE_CLOUD_PROJECT || '${GCP_PROJECT_ID}';
    const name = \`projects/\${projectId}/secrets/\${FIREBASE_CONFIG_SECRET}/versions/latest\`;
    
    const [version] = await client.accessSecretVersion({ name });
    const payload = version.payload?.data?.toString() || '';
    
    if (!payload) {
      throw new Error('Secret payload is empty');
    }
    
    return JSON.parse(payload) as FirebaseConfig;
  } catch (error) {
    console.error('Failed to get Firebase config:', error);
    throw error;
  }
};

// Store Firebase config in Secret Manager (for initial setup)
export const storeSecretConfig = async (config: FirebaseConfig): Promise<void> => {
  try {
    const client = getSecretManagerClient();
    const projectId = process.env.GOOGLE_CLOUD_PROJECT || '${GCP_PROJECT_ID}';
    const parent = \`projects/\${projectId}\`;
    
    // Create secret if it doesn't exist
    try {
      await client.getSecret({
        name: \`\${parent}/secrets/\${FIREBASE_CONFIG_SECRET}\`
      });
    } catch (error) {
      await client.createSecret({
        parent,
        secretId: FIREBASE_CONFIG_SECRET,
        secret: {
          replication: {
            automatic: {}
          }
        }
      });
    }
    
    // Add new version
    await client.addSecretVersion({
      parent: \`\${parent}/secrets/\${FIREBASE_CONFIG_SECRET}\`,
      payload: {
        data: Buffer.from(JSON.stringify(config))
      }
    });
    
    console.log('Firebase config stored in Secret Manager');
  } catch (error) {
    console.error('Failed to store Firebase config:', error);
    throw error;
  }
};
EOL

# Create Firebase Functions directory
echo "🚀 Setting up Firebase Functions..."
mkdir -p $REPO_ROOT/functions
mkdir -p $REPO_ROOT/functions/src

# Create functions package.json
cat > $REPO_ROOT/functions/package.json << EOL
{
  "name": "functions",
  "scripts": {
    "lint": "eslint --ext .js,.ts .",
    "build": "tsc",
    "build:watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^11.8.0",
    "firebase-functions": "^4.3.1",
    "@google-cloud/secret-manager": "^4.2.1"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^5.12.0",
    "@typescript-eslint/parser": "^5.12.0",
    "eslint": "^8.9.0",
    "eslint-config-google": "^0.14.0",
    "eslint-plugin-import": "^2.25.4",
    "firebase-functions-test": "^3.1.0",
    "typescript": "^4.9.0"
  },
  "private": true
}
EOL

# Create functions tsconfig.json
cat > $REPO_ROOT/functions/tsconfig.json << EOL
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2017",
    "esModuleInterop": true
  },
  "compileOnSave": true,
  "include": [
    "src"
  ]
}
EOL

# Create functions index.ts
cat > $REPO_ROOT/functions/src/index.ts << EOL
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { SecretManagerServiceClient } from "@google-cloud/secret-manager";

// Initialize Firebase Admin
admin.initializeApp();

// Secret Manager client
const secretManagerClient = new SecretManagerServiceClient();

// Get a secret from Secret Manager
async function getSecret(secretName: string): Promise<string> {
  const projectId = process.env.GOOGLE_CLOUD_PROJECT || "${GCP_PROJECT_ID}";
  const name = \`projects/\${projectId}/secrets/\${secretName}/versions/latest\`;
  
  const [version] = await secretManagerClient.accessSecretVersion({ name });
  const payload = version.payload?.data?.toString() || "";
  
  if (!payload) {
    throw new Error("Secret payload is empty");
  }
  
  return payload;
}

// Example HTTP function that uses Secret Manager
export const secretExample = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }
  
  try {
    // This is just an example - in a real scenario, you might use this secret
    // to authenticate with an external API or service
    const exampleSecret = await getSecret("example-api-key");
    
    // Don't return the actual secret in the response!
    return { success: true, message: "Secret accessed successfully" };
  } catch (error) {
    console.error("Error accessing secret:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to access secret"
    );
  }
});

// Example Firestore trigger function
export const onUserCreate = functions.firestore
  .document("users/{userId}")
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;
    const userData = snapshot.data();
    
    // Create a private document for the user
    await admin.firestore().collection("users").doc(userId).collection("private").doc("profile").set({
      email: userData.email,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(\`Created private profile for user \${userId}\`);
    return null;
  });
EOL

# Create sample .env file for local development
cat > $REPO_ROOT/.env.example << EOL
# Firebase local development
FIREBASE_USE_EMULATORS=true

# Google Cloud
GOOGLE_CLOUD_PROJECT=${GCP_PROJECT_ID}
EOL

# Create deployment script
mkdir -p $REPO_ROOT/scripts

cat > $REPO_ROOT/scripts/deploy-firebase.sh << EOL
#!/bin/bash
# Script to deploy Firebase project using Google Cloud authentication
# This avoids storing sensitive credentials in environment files

set -e # Exit on error

# Get Firebase configuration and save to Secret Manager if needed
echo "🔒 Checking Firebase configuration in Secret Manager..."
gcloud secrets describe firebase-config --project=${GCP_PROJECT_ID} &>/dev/null || {
  echo "Creating Firebase configuration secret..."
  
  # Get Firebase configuration
  FIREBASE_CONFIG=\$(firebase apps:sdkconfig web --json)
  
  # Create secret
  echo \$FIREBASE_CONFIG | gcloud secrets create firebase-config --data-file=- --project=${GCP_PROJECT_ID}
  
  echo "✅ Firebase configuration saved to Secret Manager"
}

# Deploy Firebase project
echo "🚀 Deploying Firebase project..."
firebase deploy --project=${GCP_PROJECT_ID}

echo "✅ Firebase deployment complete"
EOL

chmod +x $REPO_ROOT/scripts/deploy-firebase.sh

# Update package.json with Firebase scripts
if [ -f "$REPO_ROOT/package.json" ]; then
  echo "📦 Updating package.json with Firebase scripts..."
  
  # Use temporary file for package.json manipulation
  TMP_FILE=$(mktemp)
  
  # Extract the scripts section
  SCRIPTS_SECTION=$(grep -A 20 '"scripts":' $REPO_ROOT/package.json | grep -B 20 -m 1 '}' | sed 's/},$/}/')
  
  # Add Firebase scripts
  NEW_SCRIPTS=$(echo "$SCRIPTS_SECTION" | sed 's/}$/,\n    "firebase:emulators": "firebase emulators:start",\n    "firebase:deploy": ".\/scripts\/deploy-firebase.sh",\n    "firebase:setup": "firebase setup:emulators:firestore && firebase setup:emulators:storage"\n  }/')
  
  # Replace scripts section in package.json
  sed "s/$SCRIPTS_SECTION/$NEW_SCRIPTS/" $REPO_ROOT/package.json > $TMP_FILE
  mv $TMP_FILE $REPO_ROOT/package.json
  
  # Add Firebase dependencies
  yarn add firebase
  yarn add -D @google-cloud/secret-manager
fi

# Initialize Firebase features
echo "🔧 Enabling Firebase features..."
firebase --project=$GCP_PROJECT_ID firestore:databases:create --location=$FIRESTORE_LOCATION
firebase --project=$GCP_PROJECT_ID storage:buckets:create
firebase --project=$GCP_PROJECT_ID auth:import --hash-algo=BCRYPT src/mock_data/users.json || echo "No users to import, skipping."

# Setup Firebase Auth providers
echo "🔐 Enabling Firebase Authentication providers..."
firebase --project=$GCP_PROJECT_ID auth:enable email
firebase --project=$GCP_PROJECT_ID auth:enable google

# Setup emulators
echo "🧪 Setting up Firebase emulators..."
firebase setup:emulators:firestore
firebase setup:emulators:storage

echo "✅ Firebase project initialization complete!"
echo "📝 Next steps:"
echo "  1. Run 'yarn firebase:emulators' to start the Firebase emulators"
echo "  2. Run 'yarn firebase:deploy' to deploy your project to Firebase"
echo "  3. Import your service account key to work with Google Secret Manager"
echo "     (Use Firebase console > Project Settings > Service accounts)"
echo ""
echo "🚀 Happy coding!"