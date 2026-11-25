import React, { useState } from "react";
import {
  ActivityIndicator,
  Alert,
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

import { FigmaSvg } from "@/components/figma-assets";
import { AppleIcon, GoogleIcon, GradientWave, LitLogo } from "@/components/lit-brand";
import { useAppAuth } from "@/lib/auth-state";

export type AuthMode = "signin" | "signup" | "recover" | "update";

interface AuthFlowProps {
  initialMode?: AuthMode;
  onSuccess?: () => void;
}

function maskEmailForDisplay(rawEmail: string): string {
  const trimmed = rawEmail.trim();
  if (!trimmed || !trimmed.includes("@")) {
    return "e***@gmail.com**";
  }
  const [local, domain] = trimmed.split("@");
  const firstChar = local?.[0] ?? "e";
  return `${firstChar}***@${domain}**`;
}

export function AuthFlow({ initialMode = "signin", onSuccess }: AuthFlowProps) {
  const insets = useSafeAreaInsets();
  const { signIn, signUp, resetPasswordForEmail, updatePassword, socialSignIn } = useAppAuth();
  const [mode, setMode] = useState<AuthMode>(initialMode);

  const [name, setName] = useState("");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [acceptedTerms, setAcceptedTerms] = useState(true);
  const [resetLinkSent, setResetLinkSent] = useState(false);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const resetState = (newMode: AuthMode) => {
    setError(null);
    setSuccessMessage(null);
    setResetLinkSent(false);
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
      setResetLinkSent(true);
    }
  };

  const handleUpdatePassword = async () => {
    if (!newPassword) {
      setError("Please enter a new password.");
      return;
    }
    if (newPassword !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);
    const res = await updatePassword(newPassword);
    setIsLoading(false);
    if (!res.success) {
      setError(res.error || "Failed to update password.");
    } else {
      setSuccessMessage("Password updated! You can now sign in.");
      resetState("signin");
    }
  };

  const isSignIn = mode === "signin";
  const isSignUp = mode === "signup";
  const isRecover = mode === "recover";
  const isUpdate = mode === "update";

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      style={styles.root}
    >
      {/* Top full-bleed blurred wave matching Figma (283:612 / 283:667) */}
      <GradientWave variant="top" height={275} />

      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          {
            paddingTop: Math.max(insets.top, 32),
            paddingBottom: Math.max(insets.bottom + 20, 24),
          },
        ]}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.canvas}>
          {/* ── Back button (Recover & Update Password screens: 283:749 / 283:783) ── */}
          {(isRecover || isUpdate) && (
            <Pressable
              style={styles.backRow}
              onPress={() => resetState("signin")}
              hitSlop={12}
            >
              <View style={styles.backCircle}>
                <FigmaSvg name="icon_back_chevron" />
              </View>
              <Text style={styles.backLabel}>Back to Sign In</Text>
            </Pressable>
          )}

          {/* ── Main 335px Content Container (top: 100px in Figma) ── */}
          <View
            style={[
              styles.panel,
              (isRecover || isUpdate) ? styles.panelWithBack : styles.panelDefault,
            ]}
          >
            {/* ── Logo + Headline (283:614 / 283:669 / 283:732 / 283:791 / 283:757) ── */}
            <View style={styles.headerBlock}>
              <LitLogo />
              <View style={styles.headlineWrap}>
                <Text style={styles.headline}>
                  {isSignIn
                    ? "Your community is waiting for you"
                    : isSignUp
                      ? "Join the scene. Create your vibe"
                      : isRecover && resetLinkSent
                        ? "We'll get you back in."
                        : "Need a new password?"}
                </Text>
                {isRecover && !resetLinkSent && (
                  <Text style={styles.subHeadline}>
                    No worries. Enter your email below to receive reset instructions.
                  </Text>
                )}
                {isUpdate && (
                  <Text style={styles.subHeadline}>
                    Almost there! Set a new password to regain access to your account.
                  </Text>
                )}
              </View>
            </View>

            {/* ── Feedback banners ── */}
            {error ? (
              <View style={styles.errorBanner}>
                <Text style={styles.errorText}>{error}</Text>
              </View>
            ) : null}
            {successMessage ? (
              <View style={styles.successBanner}>
                <Text style={styles.successText}>{successMessage}</Text>
              </View>
            ) : null}

            {/* ── Form Container ── */}
            <View style={[styles.formContainer, isSignUp && { gap: 24 }]}>
              <View style={styles.topFormContainer}>
                <View style={styles.upperFormContainer}>
                  <View style={styles.fieldsStack}>
                    {/* Sign-Up: Full Name + Username (283:678, gap 16) */}
                    {isSignUp && (
                      <View style={styles.nameRow}>
                        <View style={styles.nameCol}>
                          <View style={styles.labelWrap}>
                            <Text style={styles.label}>Full Name</Text>
                          </View>
                          <View style={styles.pill}>
                            <TextInput
                              style={styles.input}
                              value={name}
                              onChangeText={setName}
                              placeholder="Enter full name"
                              placeholderTextColor="rgba(255,255,255,0.3)"
                              autoCapitalize="words"
                            />
                          </View>
                        </View>
                        <View style={styles.nameCol}>
                          <View style={styles.labelWrap}>
                            <Text style={styles.label}>Username</Text>
                          </View>
                          <View style={styles.pill}>
                            <TextInput
                              style={styles.input}
                              value={username}
                              onChangeText={setUsername}
                              placeholder="Unique username"
                              placeholderTextColor="rgba(255,255,255,0.3)"
                              autoCapitalize="none"
                            />
                          </View>
                        </View>
                      </View>
                    )}

                    {/* Email Field (Sign In, Sign Up, Recover) */}
                    {!isUpdate && (
                      <View style={styles.fieldGroup}>
                        <View style={styles.labelWrap}>
                          <Text style={styles.label}>Email</Text>
                        </View>
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
                    )}

                    {/* Password Field (Sign In + Sign Up) */}
                    {(isSignIn || isSignUp) && (
                      <View style={styles.fieldGroup}>
                        <View style={styles.labelWrap}>
                          <Text style={styles.label}>Password</Text>
                        </View>
                        <View style={[styles.pill, styles.pillRow]}>
                          <TextInput
                            style={styles.input}
                            value={password}
                            onChangeText={setPassword}
                            placeholder="••••••••••"
                            placeholderTextColor="rgba(255,255,255,0.3)"
                            secureTextEntry={!showPassword}
                            autoCapitalize="none"
                          />
                          <Pressable
                            onPress={() => setShowPassword((v) => !v)}
                            hitSlop={8}
                            style={styles.eyeBtn}
                          >
                            <FigmaSvg name="icon_eye_off" />
                          </Pressable>
                        </View>
                      </View>
                    )}

                    {/* Update Password Fields (283:765) */}
                    {isUpdate && (
                      <>
                        <View style={styles.fieldGroup}>
                          <View style={styles.labelWrap}>
                            <Text style={styles.label}>New Password</Text>
                          </View>
                          <View style={[styles.pill, styles.pillRow]}>
                            <TextInput
                              style={styles.input}
                              value={newPassword}
                              onChangeText={setNewPassword}
                              placeholder="••••••••••"
                              placeholderTextColor="rgba(255,255,255,0.3)"
                              secureTextEntry={!showPassword}
                              autoCapitalize="none"
                            />
                            <Pressable
                              onPress={() => setShowPassword((v) => !v)}
                              hitSlop={8}
                              style={styles.eyeBtn}
                            >
                              <FigmaSvg name="icon_eye_off" />
                            </Pressable>
                          </View>
                        </View>
                        <View style={styles.fieldGroup}>
                          <View style={styles.labelWrap}>
                            <Text style={styles.label}>Confirm Password</Text>
                          </View>
                          <View style={[styles.pill, styles.pillRow]}>
                            <TextInput
                              style={styles.input}
                              value={confirmPassword}
                              onChangeText={setConfirmPassword}
                              placeholder="••••••••••"
                              placeholderTextColor="rgba(255,255,255,0.3)"
                              secureTextEntry={!showConfirmPassword}
                              autoCapitalize="none"
                            />
                            <Pressable
                              onPress={() => setShowConfirmPassword((v) => !v)}
                              hitSlop={8}
                              style={styles.eyeBtn}
                            >
                              <FigmaSvg name="icon_eye_off" />
                            </Pressable>
                          </View>
                        </View>
                      </>
                    )}
                  </View>

                  {/* Remember Me + Need help signing in? (283:636) */}
                  {isSignIn && (
                    <View style={styles.optionsRow}>
                      <Pressable
                        style={styles.rememberRow}
                        onPress={() => setRememberMe((v) => !v)}
                        hitSlop={8}
                      >
                        {rememberMe ? (
                          <FigmaSvg name="icon_checkbox_checked" />
                        ) : (
                          <View style={styles.uncheckedCircle} />
                        )}
                        <Text style={styles.rememberLabel}>Remember me</Text>
                      </Pressable>
                      <Pressable onPress={() => resetState("recover")} hitSlop={8}>
                        <Text style={styles.needHelpLink}>Need help signing in?</Text>
                      </Pressable>
                    </View>
                  )}

                  {/* Terms Checkbox Row (283:701) */}
                  {isSignUp && (
                    <Pressable
                      style={styles.termsRow}
                      onPress={() => setAcceptedTerms((v) => !v)}
                      hitSlop={8}
                    >
                      {acceptedTerms ? (
                        <FigmaSvg name="icon_checkbox_checked" />
                      ) : (
                        <View style={styles.uncheckedCircle} />
                      )}
                      <Text style={styles.termsText}>
                        Creating an account means you accept our{" "}
                        <Text style={styles.termsLink}>Terms</Text> of Use and{" "}
                        <Text style={styles.termsLink}>Privacy Policy</Text>.
                      </Text>
                    </Pressable>
                  )}
                </View>

                {/* Primary Orange Button (283:643 / 283:706 / 283:747 / 283:781) */}
                <Pressable
                  style={({ pressed }) => [
                    styles.primaryBtn,
                    pressed && { opacity: 0.88 },
                  ]}
                  disabled={isLoading}
                  onPress={
                    isSignIn
                      ? handleSignIn
                      : isSignUp
                        ? handleSignUp
                        : isRecover
                          ? handleRecoverPassword
                          : handleUpdatePassword
                  }
                >
                  {isLoading ? (
                    <ActivityIndicator color="#FFFFFF" size="small" />
                  ) : (
                    <Text style={styles.primaryBtnText}>
                      {isSignIn
                        ? "Sign In"
                        : isSignUp
                          ? "Join LIT"
                          : isRecover
                            ? "Send Reset Link"
                            : "Update Password"}
                    </Text>
                  )}
                </Pressable>
              </View>

              {/* ── Social Sign-In Options (Sign In & Create Account: 283:645 / 283:649) ── */}
              {(isSignIn || isSignUp) && (
                <>
                  <View style={styles.dividerRow}>
                    <View style={styles.dividerLine} />
                    <Text style={styles.dividerText}>or continue with</Text>
                    <View style={styles.dividerLine} />
                  </View>

                  <View style={styles.socialStack}>
                    <Pressable
                      style={({ pressed }) => [
                        styles.socialBtn,
                        pressed && { opacity: 0.8 },
                      ]}
                      onPress={() => handleSocial("google")}
                    >
                      <GoogleIcon />
                      <Text style={styles.socialBtnText}>Sign In</Text>
                    </Pressable>

                    <Pressable
                      style={({ pressed }) => [
                        styles.socialBtn,
                        pressed && { opacity: 0.8 },
                      ]}
                      onPress={() => handleSocial("apple")}
                    >
                      <AppleIcon />
                      <Text style={styles.socialBtnText}>Sign In</Text>
                    </Pressable>
                  </View>
                </>
              )}
            </View>
          </View>

          {/* ── Bottom Switch Link (283:663 / 283:726) ── */}
          {(isSignIn || isSignUp) && (
            <View style={styles.footerRow}>
              <Text style={styles.footerText}>
                {isSignIn ? "Don’t have an Account?" : "Already have an Account?"}
              </Text>
              <Pressable
                onPress={() => resetState(isSignIn ? "signup" : "signin")}
                hitSlop={8}
              >
                <Text style={styles.footerLink}>
                  {isSignIn ? "Create Account" : "Sign In"}
                </Text>
              </Pressable>
            </View>
          )}
        </View>
      </ScrollView>

      {/* ── Figma "Reset link sent" Modal Overlay (283:788) ── */}
      {isRecover && resetLinkSent && (
        <View style={styles.modalBackdrop}>
          <View style={styles.resetModalCard}>
            <GradientWave variant="modal" height={130} />
            <Pressable
              style={styles.resetModalClose}
              onPress={() => {
                setResetLinkSent(false);
                setMode("update");
              }}
              hitSlop={12}
            >
              <FigmaSvg name="icon_close" />
            </Pressable>
            <View style={styles.resetModalContent}>
              <FigmaSvg name="icon_mailbox" />
              <View style={styles.resetModalTextWrap}>
                <Text style={styles.resetModalTitle}>{`You're Almost There!`}</Text>
                <Text style={styles.resetModalSub}>
                  {`We've emailed instructions to help you regain access to your account. ${maskEmailForDisplay(email)}`}
                </Text>
              </View>
            </View>
          </View>
        </View>
      )}
    </KeyboardAvoidingView>
  );
}

const PANEL_W = 335;

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: "#07070E",
  },
  scroll: {
    flexGrow: 1,
    alignItems: "center",
  },
  canvas: {
    width: 375,
    maxWidth: "100%",
    minHeight: 756,
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 20,
  },
  panel: {
    width: PANEL_W,
    gap: 40,
    alignItems: "center",
  },
  panelDefault: {
    marginTop: 68,
  },
  panelWithBack: {
    marginTop: 32,
  },

  /* Back button (283:749) */
  backRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    alignSelf: "flex-start",
  },
  backCircle: {
    width: 36,
    height: 36,
    borderRadius: 88,
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
  },
  backLabel: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
  },

  /* Header (283:614) */
  headerBlock: {
    alignItems: "center",
    gap: 16,
  },
  headlineWrap: {
    alignItems: "center",
    gap: 4,
  },
  headline: {
    color: "#FFFFFF",
    fontSize: 20,
    fontWeight: "500",
    textAlign: "center",
    lineHeight: 24,
  },
  subHeadline: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 14,
    fontWeight: "400",
    textAlign: "center",
    lineHeight: 16.8,
    width: 257,
  },

  /* Feedback banners */
  errorBanner: {
    width: "100%",
    backgroundColor: "rgba(239,68,68,0.14)",
    borderWidth: 1,
    borderColor: "rgba(239,68,68,0.35)",
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginTop: -26,
    marginBottom: -14,
  },
  errorText: {
    color: "#FF8787",
    fontSize: 12,
    lineHeight: 16,
    textAlign: "center",
  },
  successBanner: {
    width: "100%",
    backgroundColor: "rgba(81,207,102,0.14)",
    borderWidth: 1,
    borderColor: "rgba(81,207,102,0.35)",
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginTop: -26,
    marginBottom: -14,
  },
  successText: {
    color: "#69DB7C",
    fontSize: 12,
    lineHeight: 16,
    textAlign: "center",
  },

  /* Form layout (283:619) */
  formContainer: {
    width: "100%",
    gap: 32,
  },
  topFormContainer: {
    width: "100%",
    gap: 24,
  },
  upperFormContainer: {
    width: "100%",
    gap: 12,
  },
  fieldsStack: {
    width: "100%",
    gap: 16,
  },
  nameRow: {
    flexDirection: "row",
    gap: 16,
    width: "100%",
  },
  nameCol: {
    flex: 1,
    gap: 8,
  },
  fieldGroup: {
    width: "100%",
    gap: 8,
  },
  labelWrap: {
    paddingHorizontal: 12,
    width: "100%",
  },
  label: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "400",
  },
  pill: {
    height: 45,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 13,
    justifyContent: "center",
  },
  pillRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  input: {
    color: "#FFFFFF",
    fontSize: 14,
    lineHeight: 20,
    padding: 0,
    flex: 1,
    ...(Platform.OS === "web" ? ({ outlineStyle: "none" } as any) : {}),
  },
  eyeBtn: {
    width: 20,
    height: 20,
    alignItems: "center",
    justifyContent: "center",
    marginLeft: 8,
  },

  /* Remember me & Need help row (283:636) */
  optionsRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
    width: "100%",
  },
  rememberRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    flex: 1,
  },
  uncheckedCircle: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: "rgba(255,255,255,0.3)",
    backgroundColor: "rgba(255,255,255,0.05)",
  },
  rememberLabel: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "400",
  },
  needHelpLink: {
    color: "#6780FF",
    fontSize: 14,
    fontWeight: "500",
    textAlign: "right",
  },

  /* Terms row (283:701) */
  termsRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    width: "100%",
  },
  termsText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "400",
    lineHeight: 16,
    width: 299,
  },
  termsLink: {
    color: "#6780FF",
  },

  /* Primary Button (283:643) */
  primaryBtn: {
    backgroundColor: "#ED4113",
    borderRadius: 88,
    padding: 12,
    height: 44,
    alignItems: "center",
    justifyContent: "center",
    width: "100%",
  },
  primaryBtnText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
    textAlign: "center",
  },

  /* Divider (283:645) */
  dividerRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    width: "100%",
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: "rgba(255,255,255,0.1)",
  },
  dividerText: {
    color: "rgba(255,255,255,0.4)",
    fontSize: 12,
    lineHeight: 16,
  },

  /* Social Buttons (283:649) */
  socialStack: {
    width: "100%",
    gap: 16,
  },
  socialBtn: {
    height: 45,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingHorizontal: 12,
    paddingTop: 12,
    paddingBottom: 13,
    width: "100%",
  },
  socialBtnText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
  },

  /* Footer (283:663 / 283:726) */
  footerRow: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    gap: 8,
    marginTop: 32,
  },
  footerText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "400",
  },
  footerLink: {
    color: "#6780FF",
    fontSize: 14,
    fontWeight: "500",
  },

  /* Reset Link Sent Modal (283:788) */
  modalBackdrop: {
    position: "absolute",
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    backgroundColor: "rgba(255,255,255,0.4)",
    alignItems: "center",
    justifyContent: "flex-end",
    paddingBottom: 20,
  },
  resetModalCard: {
    width: 335,
    height: 263,
    backgroundColor: "#07070E",
    borderRadius: 30,
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    overflow: "hidden",
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
  },
  resetModalClose: {
    position: "absolute",
    top: 15,
    right: 17,
    width: 36,
    height: 36,
    borderRadius: 88,
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
    zIndex: 10,
  },
  resetModalContent: {
    width: 291,
    alignItems: "center",
    gap: 16,
  },
  resetModalTextWrap: {
    width: "100%",
    alignItems: "center",
    gap: 4,
  },
  resetModalTitle: {
    color: "#FFFFFF",
    fontSize: 24,
    fontWeight: "500",
    lineHeight: 28.8,
    textAlign: "center",
  },
  resetModalSub: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "400",
    lineHeight: 19.2,
    textAlign: "center",
  },
});
