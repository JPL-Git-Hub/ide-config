/**
 * ESLint configuration for Client Portal System
 * Balanced for AI-assisted development in a monorepo architecture
 */
module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true,
    },
    // For monorepo, need these settings for proper project resolution
    project: ['./tsconfig.json', './packages/*/tsconfig.json'],
    tsconfigRootDir: __dirname,
  },
  env: {
    browser: true,
    node: true,
    es2020: true,
  },
  // Global settings for plugins
  settings: {
    react: {
      version: 'detect', // Auto-detect React version from package.json
    },
    'import/resolver': {
      typescript: {}, // Use TSConfig paths
      node: {
        extensions: ['.js', '.jsx', '.ts', '.tsx'],
        moduleDirectory: ['node_modules', 'packages/*/', 'src/'],
      },
    },
    // For monorepo package detection
    'import/internal-regex': '^@(frontend|backend|shared)/',
  },
  // Base configurations - order matters!
  extends: [
    'eslint:recommended', // Base ESLint rules
    'plugin:@typescript-eslint/recommended', // TypeScript recommendations
    // REMOVED strict type checking - too restrictive for AI development
    // 'plugin:@typescript-eslint/recommended-requiring-type-checking',
    'plugin:react/recommended', // React recommendations
    'plugin:react-hooks/recommended', // React hooks best practices
    'plugin:import/errors', // Import validation
    'plugin:import/warnings',
    'plugin:import/typescript', // TypeScript import validation
    'prettier', // MUST be last to override formatting rules
  ],
  plugins: [
    '@typescript-eslint',
    'react',
    'react-hooks',
    'import',
    'prettier',
  ],
  // Base rules applicable to all files
  rules: {
    // -----------------------------------------------
    // TypeScript rules - more flexible for AI dev
    // -----------------------------------------------
    '@typescript-eslint/explicit-module-boundary-types': 'off', // RELAXED: Allow type inference for exported functions
    '@typescript-eslint/no-explicit-any': 'warn', // Only warn on 'any' type usage
    '@typescript-eslint/no-unused-vars': ['warn', { 
      argsIgnorePattern: '^_',
      varsIgnorePattern: '^_',
      ignoreRestSiblings: true,
    }], // Warn but don't error on unused variables
    '@typescript-eslint/no-non-null-assertion': 'off', // RELAXED: Allow non-null assertions (!) for AI development
    '@typescript-eslint/ban-ts-comment': ['warn', { // RELAXED: Allow but warn on TS directive comments
      'ts-ignore': 'allow-with-description',
      'ts-expect-error': 'allow-with-description',
    }],
    '@typescript-eslint/no-empty-function': 'off', // RELAXED: Allow empty functions for stubs/placeholders
    
    // REMOVED strict boolean checks - too restrictive for AI development
    // '@typescript-eslint/strict-boolean-expressions': 'error',
    
    // IMPORTANT real error prevention
    '@typescript-eslint/no-floating-promises': 'error', // Prevent unhandled promises (real bug source)
    '@typescript-eslint/no-misused-promises': 'error', // Prevent promise misuse
    
    // -----------------------------------------------
    // React rules - focused on preventing real bugs
    // -----------------------------------------------
    'react/prop-types': 'off', // Not needed with TypeScript
    'react/react-in-jsx-scope': 'off', // Not needed with React 17+
    'react-hooks/rules-of-hooks': 'error', // Critical hooks rule - prevents real bugs
    'react-hooks/exhaustive-deps': 'warn', // Dependency warnings for useEffect/useCallback
    'react/no-array-index-key': 'warn', // Warn about index as key anti-pattern
    'react/jsx-key': 'error', // Require keys in iterators
    'react/no-direct-mutation-state': 'error', // Prevent state mutations
    'react/jsx-uses-react': 'off', // Not needed with new JSX transform
    'react/jsx-uses-vars': 'error', // Prevent react var false positives
    
    // -----------------------------------------------
    // Import rules - critical for monorepo architecture
    // -----------------------------------------------
    'import/order': ['warn', { // RELAXED to warn for better DX
      'groups': ['builtin', 'external', 'internal', 'parent', 'sibling', 'index'],
      'pathGroups': [
        { 
          'pattern': '@frontend/**', 
          'group': 'internal',
          'position': 'before'
        },
        { 
          'pattern': '@backend/**', 
          'group': 'internal',
          'position': 'before'
        },
        { 
          'pattern': '@shared/**', 
          'group': 'internal',
          'position': 'before'
        }
      ],
      'newlines-between': 'always',
      'alphabetize': { order: 'asc', caseInsensitive: true }
    }],
    'import/no-unresolved': 'error', // Catch import typos
    'import/no-cycle': 'error', // IMPORTANT: Prevent circular dependencies
    'import/no-self-import': 'error', // Prevent module from importing itself
    'import/first': 'error', // Ensure imports are at top of file
    'import/no-extraneous-dependencies': [ // Keep dependencies organized by package
      'error', {
        'devDependencies': [
          '**/*.test.{ts,tsx}', 
          '**/*.spec.{ts,tsx}',
          '**/test/**',
          '**/scripts/**',
          'vite.config.ts',
          'jest.config.ts'
        ]
      }
    ],
    
    // -----------------------------------------------
    // AI-friendly rules - relaxed for better AI development
    // -----------------------------------------------
    'max-len': 'off', // Let Prettier handle this
    'no-unused-vars': 'off', // TypeScript rule handles this
    'complexity': ['warn', 20], // RELAXED: Higher threshold for AI-generated code (won't error)
    'max-depth': ['warn', 5], // RELAXED: Warn at high nesting but allow deeper for AI
    'max-lines-per-function': ['warn', 200], // RELAXED: Larger functions can be OK in AI-generated code
    'max-params': ['warn', 6], // RELAXED: Allow more parameters for AI-generated functions
    'no-console': ['warn', { allow: ['error', 'warn', 'info'] }], // Allow informational logs
    
    // -----------------------------------------------
    // Monorepo-specific rules
    // -----------------------------------------------
    'no-restricted-imports': ['error', {
      patterns: [
        {
          group: ['../*'],
          message: 'Use aliases (@frontend/*, @backend/*, @shared/*) instead of relative imports across package boundaries'
        }
      ]
    }],
    
    // -----------------------------------------------
    // Prettier integration
    // -----------------------------------------------
    'prettier/prettier': ['warn', { // RELAXED to warning to avoid interrupting workflow
      singleQuote: true,
      semi: true,
      tabWidth: 2,
      trailingComma: 'es5',
      printWidth: 100,
      bracketSpacing: true,
      arrowParens: 'avoid',
    }],
  },
  // Package-specific rule overrides
  overrides: [
    // Backend (Node/Express) specific rules
    {
      files: ['packages/backend/**/*.ts'],
      rules: {
        'no-console': 'off', // Console is appropriate on backend
        '@typescript-eslint/explicit-module-boundary-types': 'warn', // Encourage but don't require types for APIs
        'no-process-exit': 'error', // Use proper exit handling
        'node/no-deprecated-api': 'error', // Avoid deprecated Node APIs
      },
      env: {
        node: true,
      }
    },
    // Frontend (React) specific rules
    {
      files: ['packages/frontend/**/*.{ts,tsx}'],
      rules: {
        'react/jsx-filename-extension': ['error', { extensions: ['.tsx'] }], // JSX only in TSX files
        'react/forbid-dom-props': ['warn', { forbid: ['style'] }], // Prefer styled-components
        'react/no-danger': 'warn', // Warn about dangerouslySetInnerHTML
      },
      env: {
        browser: true,
      }
    },
    // Shared utility files
    {
      files: ['packages/shared/**/*.ts'],
      rules: {
        '@typescript-eslint/explicit-module-boundary-types': 'warn', // Encourage types for shared APIs
        '@typescript-eslint/no-explicit-any': 'warn', // Be more careful with types in shared code
      }
    },
    // Firebase-specific rules
    {
      files: ['**/firebase/**/*.ts', '**/services/firebase/**/*.ts'],
      rules: {
        'camelcase': 'off', // Firebase often uses snake_case
        '@typescript-eslint/no-explicit-any': 'off', // Firebase types often need any
      }
    },
    // Test files
    {
      files: ['**/*.test.{ts,tsx}', '**/*.spec.{ts,tsx}', '**/test/**/*.{ts,tsx}'],
      rules: {
        '@typescript-eslint/no-non-null-assertion': 'off', // Allow in tests
        '@typescript-eslint/no-explicit-any': 'off', // Allow in tests
        'max-lines-per-function': 'off', // Tests can be large
        'max-nested-callbacks': 'off', // Common in tests
      },
      env: {
        jest: true,
        mocha: true,
      }
    },
    // Configuration files
    {
      files: ['*.config.js', '*.config.ts', 'config/**/*.js', 'config/**/*.ts'],
      rules: {
        '@typescript-eslint/no-var-requires': 'off', // Allow require in config
        'import/no-extraneous-dependencies': 'off', // Config often needs dev dependencies
      },
      env: {
        node: true,
      }
    },
  }
};