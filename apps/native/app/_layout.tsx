import "@/global.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import * as SystemUI from "expo-system-ui";
import { HeroUINativeProvider } from "heroui-native";
import { useEffect } from "react";
import { Platform } from "react-native";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { KeyboardProvider } from "react-native-keyboard-controller";

import { AppThemeProvider } from "@/contexts/app-theme-context";
import { AuthProvider } from "@/lib/auth-state";
import { useUpdateCheck } from "@/lib/updates";

export const queryClient = new QueryClient();

export const unstable_settings = {
  anchor: "(drawer)",
};

function StackLayout() {
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: "#07070E" },
      }}
    >
      <Stack.Screen name="(drawer)" options={{ headerShown: false }} />
      <Stack.Screen name="modal" options={{ title: "Modal", presentation: "modal" }} />
    </Stack>
  );
}

export default function Layout() {
  useUpdateCheck();

  useEffect(() => {
    // Enable edge-to-edge full-screen and dark status bar on Android
    SystemUI.setBackgroundColorAsync("#07070E").catch(() => {});

    if (Platform.OS !== "web") {
      import("@/lib/notifications")
        .then(({ registerForPushNotificationsAsync }) => registerForPushNotificationsAsync())
        .catch(console.warn);
    }
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <GestureHandlerRootView style={{ flex: 1, backgroundColor: "#07070E" }}>
        <StatusBar style="light" />
        <KeyboardProvider>
          <AppThemeProvider>
            <HeroUINativeProvider>
              <AuthProvider>
                <StackLayout />
              </AuthProvider>
            </HeroUINativeProvider>
          </AppThemeProvider>
        </KeyboardProvider>
      </GestureHandlerRootView>
    </QueryClientProvider>
  );
}
