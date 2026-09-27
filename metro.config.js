const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Add glb/gltf 3D model support
config.resolver.assetExts.push('glb', 'gltf', 'wav', 'wasm', 'data', 'hdr');

module.exports = config;

