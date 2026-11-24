import * as Linking from "expo-linking";

export const appScheme = "lit-socialnetwor";

export const linking = {
  prefixes: [Linking.createURL("/"), `${appScheme}://`],
  config: {
    screens: {
      Main: "",
      Modal: "modal",
      Home: "",
      Settings: "settings",
    },
  },
};

export function getAuthRedirectUri(
  path = process.env.EXPO_PUBLIC_AUTH_REDIRECT_PATH || "auth/callback",
) {
  return Linking.createURL(path, { scheme: appScheme });
}

export function getDeepLinkUrl(path = "") {
  return Linking.createURL(path, { scheme: appScheme });
}
