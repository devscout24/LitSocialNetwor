module.exports = {
  preset: "jest-expo",
  transformIgnorePatterns: [
    "/node_modules/(?!(.bun|.pnpm|react-native|@react-native|@react-native-community|expo|@expo|@expo-google-fonts|react-navigation|@react-navigation|@sentry/react-native|native-base|@gluestack-ui|react-native-mmkv))",
    "/node_modules/react-native-reanimated/plugin/",
    "/node_modules/@react-native/babel-preset/",
  ],
};
