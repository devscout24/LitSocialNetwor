import React from "react";
import { StyleSheet, View } from "react-native";

import { AuthFlow } from "@/components/auth-flow";
import { SplashScreenView } from "@/components/lit-brand";
import { WelcomeScreen } from "@/components/welcome-screen";
import { useAppAuth } from "@/lib/auth-state";

export default function Home() {
  const { session, isLoading } = useAppAuth();

  if (isLoading) {
    return <SplashScreenView />;
  }

  return (
    <View style={styles.container}>
      {session?.user ? (
        <WelcomeScreen session={session} />
      ) : (
        <AuthFlow />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#07070E",
  },
});
