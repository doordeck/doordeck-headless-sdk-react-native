const reactNative = require('@react-native/eslint-config/flat');
const prettierRecommended = require('eslint-plugin-prettier/recommended');

module.exports = [
  {
    ignores: ['node_modules/**', 'lib/**'],
  },
  ...reactNative,
  {
    // This repo has no Flow code and eslint-plugin-ft-flow 2.x is
    // incompatible with ESLint 9's rule API.
    files: ['**/*.js', '**/*.jsx'],
    rules: {
      'ft-flow/define-flow-type': 'off',
      'ft-flow/use-flow-type': 'off',
    },
  },
  prettierRecommended,
  {
    rules: {
      'react/react-in-jsx-scope': 'off',
      'prettier/prettier': [
        'error',
        {
          quoteProps: 'consistent',
          singleQuote: true,
          tabWidth: 2,
          trailingComma: 'es5',
          useTabs: false,
        },
      ],
    },
  },
];
