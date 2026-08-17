const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const exclusionList =
  require('metro-config/private/defaults/exclusionList').default;
const pkg = require('../package.json');

const root = path.resolve(__dirname, '..');
const peerModules = Object.keys(pkg.peerDependencies ?? {});

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
module.exports = mergeConfig(getDefaultConfig(__dirname), {
  watchFolders: [root],
  resolver: {
    // Only one copy of react/react-native should be loaded, so block the
    // root's copies and force resolution to the example's own node_modules.
    blockList: exclusionList(
      peerModules.map(
        (m) =>
          new RegExp(
            `^${path.join(root, 'node_modules', m).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\/.*$`
          )
      )
    ),
    extraNodeModules: {
      // The library itself isn't installed under node_modules; resolve it
      // straight to the workspace root so the example always uses live source.
      [pkg.name]: root,
      ...peerModules.reduce((acc, name) => {
        acc[name] = path.join(__dirname, 'node_modules', name);
        return acc;
      }, {}),
    },
  },
});
