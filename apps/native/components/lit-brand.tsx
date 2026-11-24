import React from "react";
import { Dimensions, StyleSheet, View } from "react-native";
import Svg, {
  Defs,
  RadialGradient,
  Rect,
  Stop,
} from "react-native-svg";

import { FigmaSvg } from "@/components/figma-assets";

const { width: SCREEN_WIDTH } = Dimensions.get("window");

/**
 * Full-bleed circular glow that matches the Figma "Upper gradient" –
 * a large red-orange radial blob anchored to the top-right corner,
 * fading to transparent, blending with the dark background.
 */
export function GradientWave({
  height = 260,
  opacity = 1,
  position = "top-right",
  style,
}: {
  height?: number;
  opacity?: number;
  position?: "top-right" | "top-left" | "bottom-right";
  style?: any;
}) {
  const W = Math.max(SCREEN_WIDTH, 375);
  const H = height;
  const SVG_W = W * 2;
  const SVG_H = H * 1.6;

  const isBottom = position === "bottom-right";
  const isLeft = position === "top-left";
  const cx = isLeft ? 0 : SVG_W;
  const cy = isBottom ? SVG_H : 0;

  return (
    <View
      style={[
        styles.waveContainer,
        isBottom ? { top: undefined, bottom: 0 } : { top: 0 },
        { height, opacity },
        style,
      ]}
      pointerEvents="none"
    >
      <Svg
        width={SVG_W}
        height={SVG_H}
        viewBox={`0 0 ${SVG_W} ${SVG_H}`}
        style={[
          { position: "absolute" },
          isBottom ? { bottom: 0 } : { top: 0 },
          isLeft ? { left: 0 } : { right: 0 },
        ]}
        fill="none"
      >
        <Defs>
          <RadialGradient
            id="glow1"
            cx={cx}
            cy={cy}
            r={SVG_W * 0.75}
            gradientUnits="userSpaceOnUse"
          >
            <Stop offset="0%" stopColor="#FF4500" stopOpacity="0.9" />
            <Stop offset="25%" stopColor="#ED4113" stopOpacity="0.7" />
            <Stop offset="55%" stopColor="#B02000" stopOpacity="0.3" />
            <Stop offset="100%" stopColor="#07070E" stopOpacity="0" />
          </RadialGradient>
          <RadialGradient
            id="glow2"
            cx={cx}
            cy={cy}
            r={SVG_W * 0.45}
            gradientUnits="userSpaceOnUse"
          >
            <Stop offset="0%" stopColor="#FF7040" stopOpacity="0.85" />
            <Stop offset="40%" stopColor="#ED4113" stopOpacity="0.5" />
            <Stop offset="100%" stopColor="#07070E" stopOpacity="0" />
          </RadialGradient>
        </Defs>
        <Rect x={0} y={0} width={SVG_W} height={SVG_H} fill="url(#glow1)" />
        <Rect x={0} y={0} width={SVG_W} height={SVG_H} fill="url(#glow2)" />
      </Svg>
    </View>
  );
}

/**
 * Exact Figma Auth Logo (`283:615` / `logo-full.svg`, natural 134x56; or `283:858` / `logo-header.svg`, natural 73x32).
 */
export function LitLogo({
  variant = "auth",
}: {
  variant?: "auth" | "header";
  width?: number;
  height?: number;
}) {
  if (variant === "header") {
    return <FigmaSvg name="logo_header" />;
  }
  return <FigmaSvg name="logo_full" />;
}

/**
 * Exact Figma Splash Screen (`283:573`) with upper + lower glows,
 * orange gradient wolf-in-flame mark (`283:585`), LIT wordmark (`283:587`),
 * and VIBE - SHARE - CONNECT tagline (`283:592`).
 */
export function SplashScreenView() {
  return (
    <View style={styles.splashRoot}>
      <GradientWave height={320} position="top-left" />
      <GradientWave height={320} position="bottom-right" />
      <View style={styles.splashCenter}>
        <FigmaSvg name="splash_wolf" />
        <View style={styles.splashWordmarkGroup}>
          <FigmaSvg name="splash_lit_wordmark" />
          <FigmaSvg name="splash_tagline" />
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
