import React from "react";
import { Image, StyleSheet, View } from "react-native";

import { FIGMA_IMAGES, FigmaSvg } from "@/components/figma-assets";

/**
 * Pixel-accurate Figma "Upper gradient" / "Bottom gradient" wave (`283:612`, `283:667`, `283:834`, `283:574`, `283:581`, `283:813`).
 *
 * Uses @2x RGBA surface assets fitted directly to the Figma Gaussian-blurred (`stdDeviation=101.5px`)
 * `mix-blend-mode: plus-lighter` wave render over `#07070E`, with a smooth alpha + RGB taper to zero
 * so there is never a horizontal clipping boundary.
 */
export function GradientWave({
  height,
  opacity = 1,
  position = "top-right",
  variant,
  style,
}: {
  height?: number;
  opacity?: number;
  position?: "top-right" | "top-left" | "bottom-right";
  variant?: "top" | "splash-top" | "splash-bottom" | "modal";
  style?: any;
}) {
  const resolvedVariant =
    variant ??
    (position === "bottom-right"
      ? "splash-bottom"
      : position === "top-left"
        ? "splash-top"
        : "top");

  const isBottom = resolvedVariant === "splash-bottom";
  const defaultHeight =
    resolvedVariant === "modal"
      ? 130
      : resolvedVariant === "splash-top"
        ? 245
        : resolvedVariant === "splash-bottom"
          ? 248
          : 275;

  const finalHeight = height ?? defaultHeight;
  const source =
    resolvedVariant === "modal"
      ? FIGMA_IMAGES.bg_modal_wave
      : resolvedVariant === "splash-top"
        ? FIGMA_IMAGES.bg_splash_top
        : resolvedVariant === "splash-bottom"
          ? FIGMA_IMAGES.bg_splash_bottom
          : FIGMA_IMAGES.bg_top_wave;

  return (
    <View
      style={[
        styles.waveContainer,
        isBottom ? { top: undefined, bottom: 0 } : { top: 0 },
        { height: finalHeight, opacity },
        style,
      ]}
      pointerEvents="none"
    >
      <Image
        source={source}
        style={styles.waveImage}
        resizeMode="stretch"
      />
    </View>
  );
}

/**
 * Exact Figma Auth Logo (`283:615` / `logo-full.svg`, natural 134x56; or `283:858` / `logo-header.svg`, natural 73x32).
 */
export function LitLogo({
  variant = "auth",
  width,
  height,
}: {
  variant?: "auth" | "header";
  width?: number;
  height?: number;
}) {
  if (variant === "header") {
    return <FigmaSvg name="logo_header" width={width} height={height} />;
  }
  return <FigmaSvg name="logo_full" width={width} height={height} />;
}

/**
 * Exact Figma Splash Screen (`283:573`) with upper (`283:581`) + lower (`283:574`) blurred waves,
 * orange gradient wolf-in-flame mark (`283:585`, 139.54x183.64), LIT wordmark (`283:587`, 139.54x60),
 * and VIBE - SHARE - CONNECT tagline (`283:592`, 128x10.47).
 */
export function SplashScreenView() {
  return (
    <View style={styles.splashRoot}>
      <GradientWave variant="splash-top" height={245} />
      <GradientWave variant="splash-bottom" height={248} />
      <View style={styles.splashCenter}>
        <FigmaSvg name="splash_wolf" width={139.54} height={183.64} />
        <View style={styles.splashWordmarkGroup}>
          <FigmaSvg name="splash_lit_wordmark" width={139.54} height={60} />
          <FigmaSvg name="splash_tagline" width={128} height={10.47} />
        </View>
      </View>
    </View>
  );
}

export function GoogleIcon() {
  return <FigmaSvg name="google_icon" />;
}

export function AppleIcon() {
  return <FigmaSvg name="apple_icon" />;
}

const styles = StyleSheet.create({
  waveContainer: {
    position: "absolute",
    left: 0,
    right: 0,
    width: "100%",
    overflow: "hidden",
  },
  waveImage: {
    width: "100%",
    height: "100%",
  },
  splashRoot: {
    flex: 1,
    backgroundColor: "#07070E",
    alignItems: "center",
    justifyContent: "center",
  },
  splashCenter: {
    alignItems: "center",
    gap: 30,
  },
  splashWordmarkGroup: {
    alignItems: "center",
    gap: 15,
  },
});
