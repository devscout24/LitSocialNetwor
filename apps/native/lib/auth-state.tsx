import { TABLES, type Profile } from "@Lit-SocialNetwor/supabase";
import type { Session, User } from "@supabase/supabase-js";
import React, { createContext, useCallback, useContext, useEffect, useState } from "react";

import { getAuthRedirectUri } from "@/lib/deep-linking";
import { supabase } from "@/lib/supabase";

export interface UserSession {
  rawSession: Session;
  profile: Profile | null;
  user: {
    id: string;
    name: string;
    username?: string | null;
    email: string;
    image?: string | null;
  };
}

interface AuthContextType {
  session: UserSession | null;
  supabaseSession: Session | null;
  profile: Profile | null;
  isLoading: boolean;
  signIn: (credentials: {
    email: string;
    password?: string;
  }) => Promise<{ success: boolean; error?: string }>;
  signUp: (data: {
    name: string;
    email: string;
    password?: string;
    username?: string;
  }) => Promise<{
    success: boolean;
    error?: string;
    needsEmailConfirmation?: boolean;
  }>;
  resetPasswordForEmail: (
    email: string,
  ) => Promise<{ success: boolean; error?: string }>;
  updatePassword: (
    newPassword: string,
  ) => Promise<{ success: boolean; error?: string }>;
  socialSignIn: (
    provider: "google" | "apple",
  ) => Promise<{ success: boolean; error?: string }>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

function buildUserSession(
  rawSession: Session | null,
  profile: Profile | null,
): UserSession | null {
  if (!rawSession?.user) {
    return null;
  }

  const authUser: User = rawSession.user;
  const meta = (authUser.user_metadata ?? {}) as Record<string, unknown>;
  const metaDisplayName =
    typeof meta.display_name === "string"
      ? meta.display_name
      : typeof meta.full_name === "string"
        ? meta.full_name
        : typeof meta.name === "string"
          ? meta.name
          : null;
  const metaUsername =
    typeof meta.username === "string" ? meta.username : null;
  const metaAvatar =
    typeof meta.avatar_url === "string" ? meta.avatar_url : null;

  const emailPrefix = authUser.email ? authUser.email.split("@")[0] : "";
  const displayName =
    profile?.display_name ||
    metaDisplayName ||
    profile?.username ||
    metaUsername ||
    emailPrefix ||
    "User";

  return {
    rawSession,
    profile,
    user: {
      id: authUser.id,
      name: displayName,
      username: profile?.username ?? metaUsername ?? (emailPrefix || null),
      email: authUser.email ?? "",
      image: profile?.avatar_url ?? metaAvatar ?? null,
    },
  };
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [supabaseSession, setSupabaseSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const fetchProfile = useCallback(async (userId: string) => {
    const { data, error } = await supabase
      .from(TABLES.PROFILES)
      .select("*")
      .eq("id", userId)
      .maybeSingle();

    if (error) {
      console.warn("Failed to load profile from Supabase:", error.message);
      return null;
    }
    return data;
  }, []);

  const refreshProfile = useCallback(async () => {
    if (!supabaseSession?.user?.id) {
      setProfile(null);
      return;
    }
    const loaded = await fetchProfile(supabaseSession.user.id);
    setProfile(loaded);
  }, [fetchProfile, supabaseSession?.user?.id]);

  useEffect(() => {
    let isMounted = true;

    supabase.auth
      .getSession()
      .then(async ({ data: { session: initialSession } }) => {
        if (!isMounted) return;
        setSupabaseSession(initialSession);
        if (initialSession?.user?.id) {
          const loadedProfile = await fetchProfile(initialSession.user.id);
          if (isMounted) {
            setProfile(loadedProfile);
          }
        }
      })
      .finally(() => {
        if (isMounted) {
          setIsLoading(false);
        }
      });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, nextSession) => {
      if (!isMounted) return;
      setSupabaseSession(nextSession);
      if (nextSession?.user?.id) {
        const loadedProfile = await fetchProfile(nextSession.user.id);
        if (isMounted) {
          setProfile(loadedProfile);
        }
      } else {
        setProfile(null);
      }
    });

    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, [fetchProfile]);

  const signIn = async (credentials: { email: string; password?: string }) => {
    const email = credentials.email.trim();
    const password = credentials.password ?? "";

    if (!email) {
      return { success: false, error: "Please provide an email address." };
    }
    if (!password) {
      return { success: false, error: "Please enter your password." };
    }

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      return { success: false, error: error.message };
    }

    return { success: true };
  };

  const signUp = async (data: {
    name: string;
    email: string;
    password?: string;
    username?: string;
  }) => {
    const email = data.email.trim();
    const password = data.password ?? "";
    const displayName = data.name.trim();
    const username = data.username?.trim() || undefined;

    if (!email) {
      return { success: false, error: "Please provide an email address." };
    }
    if (!password) {
      return { success: false, error: "Please enter a password." };
    }

    const { data: signUpData, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: getAuthRedirectUri(),
        data: {
          display_name: displayName || null,
          full_name: displayName || null,
          username: username || null,
        },
      },
    });

    if (error) {
      return { success: false, error: error.message };
    }

    const needsEmailConfirmation = Boolean(
      signUpData.user && !signUpData.session,
    );

    return {
      success: true,
      needsEmailConfirmation,
    };
  };

  const resetPasswordForEmail = async (email: string) => {
    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      return { success: false, error: "Please enter your email address." };
    }

    const { error } = await supabase.auth.resetPasswordForEmail(trimmedEmail, {
      redirectTo: getAuthRedirectUri(),
    });

    if (error) {
      return { success: false, error: error.message };
    }

    return { success: true };
  };

  const updatePassword = async (newPassword: string) => {
    if (!newPassword) {
      return { success: false, error: "Please enter a new password." };
    }

    const { error } = await supabase.auth.updateUser({
      password: newPassword,
    });

    if (error) {
      return { success: false, error: error.message };
    }

    return { success: true };
  };

  const socialSignIn = async (provider: "google" | "apple") => {
    const label = provider === "google" ? "Google" : "Apple";
    return {
      success: false,
      error: `${label} sign-in is not available yet.`,
    };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setSupabaseSession(null);
    setProfile(null);
  };

  const session = buildUserSession(supabaseSession, profile);

  return (
    <AuthContext.Provider
      value={{
        session,
        supabaseSession,
        profile,
        isLoading,
        signIn,
        signUp,
        resetPasswordForEmail,
        updatePassword,
        socialSignIn,
        signOut,
        refreshProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAppAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAppAuth must be used within an AuthProvider");
  }
  return context;
}
