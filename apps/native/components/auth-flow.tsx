import { Ionicons } from "@expo/vector-icons";
import React, { useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Dimensions,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { AppleIcon, GoogleIcon, GradientWave, LitLogo } from "@/components/lit-brand";
import { useAppAuth } from "@/lib/auth-state";

const { width: SCREEN_WIDTH } = Dimensions.get("window");
void SCREEN_WIDTH;

export type AuthMode = "signin" | "signup" | "recover";

interface AuthFlowProps {
  initialMode?: AuthMode;
  onSuccess?: () => void;
}

export function AuthFlow({ initialMode = "signin", onSuccess }: AuthFlowProps) {
  const insets = useSafeAreaInsets();
  const { signIn, signUp, resetPasswordForEmail, socialSignIn } = useAppAuth();
  const [mode, setMode] = useState<AuthMode>(initialMode);

  const [name, setName] = useState("");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [acceptedTerms, setAcceptedTerms] = useState(true);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const resetState = (newMode: AuthMode) => {
    setError(null);
    setSuccessMessage(null);
    setMode(newMode);
  };

  const handleSignIn = async () => {
    if (!email.trim()) {
      setError("Please fill in your email address.");
      return;
    }
    if (!password) {
      setError("Please enter your password.");
      return;
    }
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);
    const res = await signIn({ email, password });
    setIsLoading(false);
    if (!res.success) {
      setError(res.error || "Failed to sign in.");
    } else {
      onSuccess?.();
    }
  };

  const handleSignUp = async () => {
    if (!email.trim()) {
      setError("Please fill in your email address.");
      return;
    }
    if (!password) {
      setError("Please enter a password.");
      return;
    }
    if (!acceptedTerms) {
      setError("Please accept the Terms of Use and Privacy Policy.");
      return;
    }
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);
    const res = await signUp({
      name: name.trim(),
      email: email.trim(),
      password,
      username: username.trim(),
    });
    setIsLoading(false);
    if (!res.success) {
      setError(res.error || "Failed to create account.");
    } else if (res.needsEmailConfirmation) {
      setSuccessMessage("Account created! Please check your inbox to confirm your email.");
    } else {
      onSuccess?.();
    }
  };

  const handleSocial = async (provider: "google" | "apple") => {
    setError(null);
    setSuccessMessage(null);
    const res = await socialSignIn(provider);
    if (!res.success) {
      const message = res.error || "Social sign-in is not available yet.";
      setError(message);
      if (Platform.OS !== "web") {
        Alert.alert("Not Available Yet", message);
      }
      return;
    }
    onSuccess?.();
  };

  const handleRecoverPassword = async () => {
    if (!email.trim()) {
      setError("Please enter your email address.");
      return;
    }
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);
    const res = await resetPasswordForEmail(email.trim());
    setIsLoading(false);
    if (!res.success) {
      setError(res.error || "Failed to send password reset link.");
    } else {
      setSuccessMessage("Password reset link sent! Check your inbox.");
    }
  };

  const isSignIn = mode === "signin";
  const isSignUp = mode === "signup";
  const isRecover = mode === "recover";

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      style={styles.root}
    >
      {/* Full-bleed gradient anchored top-right – no padding, matches Figma */}
      <GradientWave height={280} />

      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingTop: Math.max(insets.top + 24, 44), paddingBottom: Math.max(insets.bottom + 32, 48) },
        ]}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        {/* Inner content panel – 335px wide, centred, matching Figma Content Container */}
        <View style={styles.panel}>

          {/* ── Back button (Recover only) ── */}
          {isRecover && (
            <Pressable style={styles.backRow} onPress={() => resetState("signin")} hitSlop={12}>
              <View style={styles.backCircle}>
                <Ionicons name="arrow-back" size={18} color="#FFFFFF" />
              </View>
              <Text style={styles.backLabel}>Back to Sign In</Text>
            </Pressable>
          )}

          {/* ── Logo + headline ── */}
          <View style={styles.headerBlock}>
            <LitLogo width={134} height={56} />
            <Text style={styles.headline}>
              {isSignIn
                ? "Your community is waiting for you"
                : isSignUp
                  ? "Join the scene. Create your vibe"
                  : "Need a new password?"}
            </Text>
            {isRecover && (
              <Text style={styles.recoverSub}>
                No worries. Enter your email below to receive reset instructions.
              </Text>
            )}
          </View>

          {/* ── Feedback banners ── */}
          {error ? (
            <View style={styles.errorBanner}>
              <Ionicons name="alert-circle" size={18} color="#FF8787" />
              <Text style={styles.errorText}>{error}</Text>
            </View>
          ) : null}
          {successMessage ? (
            <View style={styles.successBanner}>
              <Ionicons name="checkmark-circle" size={18} color="#69DB7C" />
              <Text style={styles.successText}>{successMessage}</Text>
            </View>
          ) : null}

          {/* ── Form fields ── */}
          <View style={styles.formBlock}>

            {/* Sign-up: Full Name + Username */}
            {isSignUp && (
              <View style={styles.nameRow}>
                <View style={styles.nameCol}>
                  <Text style={styles.label}>Full Name</Text>
                  <View style={styles.pill}>
                    <TextInput
                      style={styles.input}
                      value={name}
                      onChangeText={setName}
                      placeholder="Full name"
                      placeholderTextColor="rgba(255,255,255,0.3)"
                      autoCapitalize="words"
                    />
                  </View>
                </View>
                <View style={styles.nameCol}>
                  <Text style={styles.label}>Username</Text>
                  <View style={styles.pill}>
                    <TextInput
                      style={styles.input}
                      value={username}
                      onChangeText={setUsername}
                      placeholder="Username"
                      placeholderTextColor="rgba(255,255,255,0.3)"
                      autoCapitalize="none"
                    />
                  </View>
                </View>
              </View>
            )}

            {/* Email */}
            <View style={styles.fieldGroup}>
              <Text style={styles.label}>Email</Text>
              <View style={styles.pill}>
                <TextInput
                  style={styles.input}
                  value={email}
                  onChangeText={setEmail}
                  placeholder="you@example.com"
                  placeholderTextColor="rgba(255,255,255,0.3)"
                  keyboardType="email-address"
                  autoCapitalize="none"
                  autoComplete="email"
                />
              </View>
            </View>

            {/* Password (Sign In + Sign Up) */}
            {!isRecover && (
              <View style={styles.fieldGroup}>
                <Text style={styles.label}>Password</Text>
                <View style={[styles.pill, styles.pillRow]}>
                  <TextInput
                    style={[styles.input, { flex: 1 }]}
                    value={password}
                    onChangeText={setPassword}
                    placeholder="••••••••••"
                    placeholderTextColor="rgba(255,255,255,0.3)"
                    secureTextEntry={!showPassword}
                    autoCapitalize="none"
                  />
                  <Pressable onPress={() => setShowPassword((v) => !v)} hitSlop={8}>
                    <Ionicons
                      name={showPassword ? "eye-off-outline" : "eye-outline"}
                      size={20}
                      color="rgba(255,255,255,0.5)"
                    />
                  </Pressable>
                </View>
              </View>
            )}

            {/* Remember Me / Need help  (Sign In only) */}
            {isSignIn && (
              <View style={styles.optionsRow}>
                <Pressable
                  style={styles.checkRow}
                  onPress={() => setRememberMe((v) => !v)}
                  hitSlop={8}
                >
                  <View style={[styles.checkbox, rememberMe && styles.checkboxOn]}>
                    {rememberMe && <Ionicons name="checkmark" size={12} color="#FFFFFF" />}
                  </View>
                  <Text style={styles.checkLabel}>Remember me</Text>
                </Pressable>
                <Pressable onPress={() => resetState("recover")} hitSlop={8}>
                  <Text style={styles.accentLink}>Need help signing in?</Text>
                </Pressable>
              </View>
            )}

            {/* Terms (Sign Up only) */}
            {isSignUp && (
              <Pressable
                style={styles.termsRow}
                onPress={() => setAcceptedTerms((v) => !v)}
                hitSlop={8}
              >
                <View style={[styles.checkbox, acceptedTerms && styles.checkboxOn]}>
                  {acceptedTerms && <Ionicons name="checkmark" size={12} color="#FFFFFF" />}
                </View>
                <Text style={styles.termsText}>
                  I agree to the{" "}
                  <Text style={styles.accentInline}>Terms of Use</Text>
                  {" "}and{" "}
                  <Text style={styles.accentInline}>Privacy Policy</Text>
                </Text>
              </Pressable>
            )}

            {/* Primary CTA */}
            <Pressable
              style={({ pressed }) => [
                styles.primaryBtn,
                pressed && { opacity: 0.88 },
              ]}
              disabled={isLoading}
              onPress={isSignIn ? handleSignIn : isSignUp ? handleSignUp : handleRecoverPassword}
            >
              {isLoading ? (
                <ActivityIndicator color="#FFFFFF" size="small" />
              ) : (
                <Text style={styles.primaryBtnText}>
                  {isSignIn ? "Sign In" : isSignUp ? "Join LIT" : "Send Reset Link"}
                </Text>
              )}
            </Pressable>
          </View>

          {/* ── Social login ── */}
          {!isRecover && (
            <>
              {/* Divider */}
              <View style={styles.dividerRow}>
                <View style={styles.dividerLine} />
                <Text style={styles.dividerText}>or continue with</Text>
                <View style={styles.dividerLine} />
              </View>

              {/* Google */}
              <Pressable
                style={({ pressed }) => [styles.socialBtn, pressed && { opacity: 0.8 }]}
                onPress={() => handleSocial("google")}
              >
                <GoogleIcon size={20} />
                <Text style={styles.socialBtnText}>Continue with Google</Text>
              </Pressable>

              {/* Apple */}
              <Pressable
                style={({ pressed }) => [styles.socialBtn, styles.socialBtnApple, pressed && { opacity: 0.8 }]}
                onPress={() => handleSocial("apple")}
              >
                <AppleIcon size={20} />
                <Text style={styles.socialBtnText}>Continue with Apple</Text>
              </Pressable>
            </>
          )}

          {/* ── Footer switch ── */}
          <View style={styles.footerRow}>
            {isSignIn ? (
              <>
                <Text style={styles.footerText}>Don't have an Account?</Text>
                <Pressable onPress={() => resetState("signup")} hitSlop={8}>
                  <Text style={styles.footerLink}> Create Account</Text>
                </Pressable>
              </>
            ) : isSignUp ? (
              <>
                <Text style={styles.footerText}>Already have an account?</Text>
                <Pressable onPress={() => resetState("signin")} hitSlop={8}>
                  <Text style={styles.footerLink}> Sign In</Text>
                </Pressable>
              </>
            ) : (
              <>
                <Text style={styles.footerText}>Remembered it?</Text>
                <Pressable onPress={() => resetState("signin")} hitSlop={8}>
                  <Text style={styles.footerLink}> Sign In</Text>
                </Pressable>
              </>
            )}
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const PANEL_W = 335;
const H_INPUT = 45;

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: "#07070E",
  },
  scroll: {
    flexGrow: 1,
    alignItems: "center",
  },
  panel: {
    width: PANEL_W,
  },

  /* Back */
  backRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    marginBottom: 20,
    alignSelf: "flex-start",
  },
  backCircle: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: "rgba(255,255,255,0.08)",
    alignItems: "center",
    justifyContent: "center",
  },
  backLabel: { color: "#FFFFFF", fontSize: 15, fontWeight: "500" },

  /* Header */
  headerBlock: {
    alignItems: "center",
    marginBottom: 40,
    gap: 16,
  },
  headline: {
    color: "#FFFFFF",
    fontSize: 20,
    fontWeight: "500",
    textAlign: "center",
    lineHeight: 24,
  },
  recoverSub: {
    color: "rgba(255,255,255,0.7)",
    fontSize: 14,
    textAlign: "center",
    lineHeight: 20,
  },

  /* Feedback */
  errorBanner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    backgroundColor: "rgba(255,107,107,0.12)",
    borderWidth: 1,
    borderColor: "rgba(255,107,107,0.3)",
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 20,
  },
  errorText: { color: "#FF8787", fontSize: 13, flex: 1 },
  successBanner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    backgroundColor: "rgba(81,207,102,0.12)",
    borderWidth: 1,
    borderColor: "rgba(81,207,102,0.3)",
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 20,
  },
  successText: { color: "#69DB7C", fontSize: 13, flex: 1 },

  /* Form */
  formBlock: { gap: 16 },
  nameRow: { flexDirection: "row", gap: 12 },
  nameCol: { flex: 1, gap: 8 },
  fieldGroup: { gap: 8 },
  label: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "400",
    paddingLeft: 4,
  },
  /* Figma: bg rgba(255,255,255,0.05), border-bottom rgba(255,255,255,0.1), rounded-[88px] */
  pill: {
    height: H_INPUT,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    paddingHorizontal: 16,
    justifyContent: "center",
  },
  pillRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingRight: 14,
  },
  input: {
    color: "#FFFFFF",
    fontSize: 14,
    padding: 0,
    flex: 1,
  },

  /* Options row */
  optionsRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: -4,
  },
  checkRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 6,
    borderWidth: 1.5,
    borderColor: "rgba(255,255,255,0.3)",
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
  },
  checkboxOn: { backgroundColor: "#ED4113", borderColor: "#ED4113" },
  checkLabel: { color: "#FFFFFF", fontSize: 14 },
  accentLink: { color: "#6780FF", fontSize: 14, fontWeight: "500" },

  /* Terms row */
  termsRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 10,
    marginTop: -4,
  },
  termsText: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 13,
    lineHeight: 18,
    flex: 1,
  },
  accentInline: { color: "#6780FF", fontWeight: "500" },

  /* Primary button – Figma: bg #ED4113, rounded-[88px], h=44 */
  primaryBtn: {
    backgroundColor: "#ED4113",
    borderRadius: 88,
    height: 44,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 8,
    shadowColor: "#ED4113",
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 6,
  },
  primaryBtnText: { color: "#FFFFFF", fontSize: 16, fontWeight: "500" },

  /* Divider */
  dividerRow: {
    flexDirection: "row",
    alignItems: "center",
    marginVertical: 24,
  },
  dividerLine: { flex: 1, height: 1, backgroundColor: "rgba(255,255,255,0.12)" },
  dividerText: {
    color: "rgba(255,255,255,0.4)",
    fontSize: 12,
    marginHorizontal: 12,
  },

  /* Social buttons – Figma: same pill style as inputs */
  socialBtn: {
    height: H_INPUT,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 10,
    marginBottom: 16,
  },
  socialBtnApple: { marginBottom: 0 },
  socialBtnText: { color: "#FFFFFF", fontSize: 16, fontWeight: "500" },

  /* Footer */
  footerRow: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    marginTop: 32,
  },
  footerText: { color: "rgba(255,255,255,0.85)", fontSize: 14 },
  footerLink: { color: "#6780FF", fontSize: 14, fontWeight: "600" },
});
