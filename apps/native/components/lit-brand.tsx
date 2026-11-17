import React from "react";
import { Dimensions, StyleSheet, View } from "react-native";
import Svg, {
  ClipPath,
  Defs,
  G,
  Path,
  RadialGradient,
  Rect,
  Stop,
} from "react-native-svg";

const { width: SCREEN_WIDTH } = Dimensions.get("window");

/**
 * Full-bleed circular glow that matches the Figma "Upper gradient" –
 * a large red-orange radial blob anchored to the top-right corner,
 * fading to transparent, blending with the dark background.
 */
export function GradientWave({
  height = 260,
  opacity = 1,
  style,
}: {
  height?: number;
  opacity?: number;
  style?: any;
}) {
  const W = SCREEN_WIDTH;
  const H = height;
  // Extend the SVG canvas to 2x the screen width so the radial gradient
  // bleeds well past the right edge — the container clips it.
  const SVG_W = W * 2;
  const SVG_H = H * 1.5;

  return (
    <View
      style={[styles.waveContainer, { height, opacity }, style]}
      pointerEvents="none"
    >
      <Svg
        width={SVG_W}
        height={SVG_H}
        viewBox={`0 0 ${SVG_W} ${SVG_H}`}
        style={{ position: "absolute", top: 0, right: 0 }}
        fill="none"
      >
        <Defs>
          {/* Outer soft glow — huge radius, anchored at top-right of original screen */}
          <RadialGradient
            id="glow1"
            cx={SVG_W}
            cy={0}
            r={SVG_W * 0.75}
            gradientUnits="userSpaceOnUse"
          >
            <Stop offset="0%" stopColor="#FF4500" stopOpacity="0.9" />
            <Stop offset="25%" stopColor="#ED4113" stopOpacity="0.7" />
            <Stop offset="55%" stopColor="#B02000" stopOpacity="0.3" />
            <Stop offset="100%" stopColor="#07070E" stopOpacity="0" />
          </RadialGradient>
          {/* Inner bright core */}
          <RadialGradient
            id="glow2"
            cx={SVG_W}
            cy={0}
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

export function LitLogo({ width = 134, height = 56 }: { width?: number; height?: number }) {
  return (
    <Svg width={width} height={height} viewBox="0 0 134 56" fill="none">
      {/* Flame mark */}
      <Path
        d="M29.8 1.84C31.7 3.35 33.26 5.38 34.04 7.72C34.32 8.58 34.52 9.45 34.55 10.36C34.63 13.03 33.49 15.57 31.89 17.64C31.57 18.03 31.25 18.43 30.92 18.81C30.1 19.77 29.52 20.84 29.2 22.07C28.96 22.98 28.77 24.33 29.62 24.99C30.23 25.46 31.31 25.54 32.05 25.43C33.25 25.25 34.33 24.59 35.05 23.6C35.98 22.32 36.09 20.65 35.59 19.16C36.88 20.37 40.03 24.84 41.46 36.1C40.83 42 37.95 47.42 33.44 51.19C30.21 53.88 26.16 55.44 22.03 55.93C21.85 55.95 21.65 55.95 21.48 56H20.41C20.77 55.72 21.48 55.41 21.91 55.15C23.11 54.42 24.53 53.42 25.03 52.02C25.67 50.35 23.64 48.58 22.22 48.18C20.17 47.59 17.77 48.31 15.94 49.29C14.75 51.38 13.49 51.82 12.42 51.97C10.08 52.83 7.82 53.01 4.76 49.72C3.79 48.28 3.19 47.71 2.65 47.07C1.58 43.25 0.66 40.88 0.22 38.42C0.12 37.3 0 37.02 0 34.35C0.53 31.43 1.05 30.02 1.76 28.71C3.42 25.62 6.27 23.17 9.19 21.36C12.92 19.19 18.65 15.91 21.45 14.15C25.44 11.59 26.8 9.74 27.4 17.51C28.16 15.86 28.91 13.97 29.8 1.84Z"
        fill="#FFFFFF"
      />
      {/* "L" in LIT */}
      <Path
        d="M64.97 6.06H74.16V12.6C73.39 18.88 70.93 21.77 68.24 25.27C67.2 26.62 66.09 28.24 64.95 29.5H86.55V38.81H58V29.46L62.71 29.46C64.23 29.49 64.92 29.48 64.92 8.45V6.06Z"
        fill="#FFFFFF"
      />
      {/* "I" in LIT – orange top bar */}
      <Path
        d="M91.52 6H100.66V11.17C100.21 13.65 98.97 16.25 97.56 18.31C96.14 20.11 94.77 21.82 91.49 24.75V6Z"
        fill="#ED4113"
      />
      <Path
        d="M91.5 38.81V33.74C91.92 30.98 93.32 28.33 94.95 26.1C96.34 24.22 98.15 22.23 99.92 20.67L100.66 20.15V38.81H91.5Z"
        fill="#FFFFFF"
      />
      {/* "T" in LIT */}
      <Path
        d="M105.61 15.32V6.09H122.48C122.81 6.1 125.58 9.1 126.03 9.56C126.4 9.92 126.81 10.23 127.15 10.63V15.32L134 6.22V15.31C131.76 15.32 129.38 15.35 127.15 15.31V38.81H117.92V15.32H105.61Z"
        fill="#FFFFFF"
      />
      {/* "SOCIAL" subtitle – simplified paths */}
      <Path d="M89.22 49.95V44.33H91.59C91.96 45.9 90.78 47.75 90.78 49.95H89.22Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M92.95 49.95V44.33H95.26V49.95H92.95Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M98.35 48.32V47.58H100V48.32H98.35Z" fill="#ED4113" />
      <Path d="M104.5 50C103.16 48.56 103.16 45.96 104.53 44.28C105.9 45.6 105.92 48.59 104.5 50Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M108.25 50C106.87 48.42 106.87 45.75 108.25 44.28C109.63 45.75 109.63 48.42 108.25 50Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M110.7 49.95V44.33H113.45V49.95H110.7Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M114.57 49.95V44.33H117.32V49.95H114.57Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M118.43 49.95V44.33H120.75V49.95H118.43Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M123.04 50C121.69 48.56 121.69 45.96 123.07 44.28C124.44 45.6 124.45 48.59 123.04 50Z" fill="#FFFFFF" opacity={0.9} />
      <Path d="M125.93 49.95V44.33H127.72V49.95H125.93Z" fill="#FFFFFF" opacity={0.9} />
    </Svg>
  );
}

export function GoogleIcon({ size = 20 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 20 20" fill="none">
      <ClipPath id="googleClip">
        <Rect width="20" height="20" fill="white" />
      </ClipPath>
      <G clipPath="url(#googleClip)">
        <Path
          d="M19.7875 10.225C19.7875 9.56667 19.7292 8.94167 19.6292 8.33333H10.2125V12.0917H15.6042C15.3625 13.325 14.6542 14.3667 13.6042 15.075V17.575H16.8208C18.7042 15.8333 19.7875 13.2667 19.7875 10.225Z"
          fill="#4285F4"
        />
        <Path
          d="M10.2125 20C12.9125 20 15.1708 19.1 16.8208 17.575L13.6042 15.075C12.7042 15.675 11.5625 16.0417 10.2125 16.0417C7.60417 16.0417 5.39583 14.2833 4.60417 11.9083H1.2875V14.4833C2.92917 17.75 6.34583 20 10.2125 20Z"
          fill="#34A853"
        />
        <Path
          d="M4.60417 11.9083C4.39583 11.3083 4.2875 10.6667 4.2875 10C4.2875 9.33333 4.40417 8.69167 4.60417 8.09167V5.51667H1.2875C0.580604 6.90543 0.212117 8.44168 0.212117 10C0.212117 11.5583 0.580604 13.0946 1.2875 14.4833L4.60417 11.9083Z"
          fill="#FBBC05"
        />
        <Path
          d="M10.2125 3.95833C11.6875 3.95833 13.0042 4.46667 14.0458 5.45833L16.8958 2.60833C15.1708 0.991666 12.9125 0 10.2125 0C6.34583 0 2.92917 2.25 1.2875 5.51667L4.60417 8.09167C5.39583 5.71667 7.60417 3.95833 10.2125 3.95833Z"
          fill="#EA4335"
        />
      </G>
    </Svg>
  );
}

export function AppleIcon({ size = 20 }: { size?: number }) {
  const w = (size * 16.34) / 20;
  return (
    <Svg width={w} height={size} viewBox="0 0 16.3443 20" fill="none">
      <Path
        d="M0.843468 7.35204C-0.847352 10.2861 0.227534 14.7388 2.0973 17.4386C3.03062 18.7884 3.97553 20 5.26976 20C5.34366 19.9985 5.95173 19.9743 6.81599 19.6061C7.29298 19.4029 7.78629 19.1927 8.56006 19.1927C9.29619 19.1927 9.76596 19.396 10.2203 19.5926C10.668 19.7863 11.1292 19.9867 11.8106 19.9739C13.2685 19.9468 14.1635 18.6394 14.9532 17.486C15.7773 16.2817 16.1907 15.1125 16.3302 14.6657C16.3486 14.6096 16.3468 14.5678 16.3308 14.5307C16.2487 14.4469 15.98 14.3368 13.7044 10.6149C13.6824 8.40266 15.3938 7.23118 15.753 7.00889C14.6183 5.05 12.8078 4.78948 12.0789 4.75814C11.7543 4.74227 10.8982 4.74227 9.41914 5.32541C8.96432 5.50476 8.57147 5.65964 8.30052 5.65964C7.99606 5.65964 7.60098 5.50286 7.14347 5.32135C6.53166 5.07853 5.83822 4.80338 5.10412 4.80338C3.3455 4.82902 1.73265 5.80555 0.843468 7.35204Z"
        fill="#FFFFFF"
      />
      <Path
        d="M12.0804 0C11.0467 0.042 9.80681 0.678 9.0657 1.5465C8.43586 2.276 7.82058 3.4927 7.98268 4.7189C8.03243 4.8164 8.20222 4.8663 8.34439 4.8691C9.35507 4.8691 10.4454 4.31 11.19 3.4096C11.9736 2.4589 12.3699 1.2389 12.25 0.146C12.1937 0.0399 12.1218 -0.0014 12.0804 0Z"
        fill="#FFFFFF"
      />
    </Svg>
  );
}

const styles = StyleSheet.create({
  waveContainer: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    width: "100%",
    overflow: "hidden",
  },
});