/**
 * Prettier configuration for Client Portal System
 * Clean, consistent, and minimal formatting across the monorepo
 */
module.exports = {
  // Essential formatting options - minimal and aligned with industry standards
  printWidth: 100,      // Reasonable line length that balances readability and space
  tabWidth: 2,          // Industry standard 2-space indentation
  useTabs: false,       // Spaces preferred over tabs for consistency across editors
  
  // Code style preferences - opinionated but widely accepted
  semi: true,           // Always use semicolons for statement termination
  singleQuote: true,    // Use single quotes for string literals
  quoteProps: 'as-needed', // Only quote object properties when necessary
  
  // Modern JavaScript/TypeScript conventions
  trailingComma: 'es5', // Add trailing commas where valid in ES5 (helps with cleaner diffs)
  bracketSpacing: true, // Spaces inside object literal braces
  arrowParens: 'avoid', // Omit parentheses when possible in arrow functions
  
  // JSX/React specific settings
  jsxSingleQuote: false, // Use double quotes in JSX (React convention)
  jsxBracketSameLine: false, // Place closing bracket on a new line in multiline JSX
  
  // Consistent wrapping
  endOfLine: 'lf',      // Unix-style line endings for cross-platform consistency
  
  // Avoid opinionated preferences that could cause frequent reformatting
  proseWrap: 'preserve' // Don't wrap prose (markdown, etc.)
};