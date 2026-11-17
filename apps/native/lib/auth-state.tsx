import * as SecureStore from "expo-secure-store";
import React, { createContext, useContext, useEffect, useState } from "react";
import { Platform } from "react-native";

export interface UserSession {
  user: {
    id: string;
    name: string;
    email: string;
    image?: string | null;
  };
}

interface AuthContextType {
  session: UserSession | null;
  isLoading: boolean;
  signIn: (credentials: { email: string; password?: string }) => Promise<{ success: boolean; error?: string }>;
  signUp: (data: { name: string; email: string; password?: string; username?: string }) => Promise<{ success: boolean; error?: string }>;
  socialSignIn: (provider: "google" | "apple") => Promise<{ success: boolean }>;
  signOut: () => Promise<void>;
}

const STORAGE_KEY = "lit_auth_session_local";

async function saveSessionToStorage(session: UserSession | null) {
  try {
    if (session) {
      const serialized = JSON.stringify(session);
      if (Platform.OS === "web") {
        if (typeof window !== "undefined" && window.localStorage) {
          window.localStorage.setItem(STORAGE_KEY, serialized);
        }
      } else {
        await SecureStore.setItemAsync(STORAGE_KEY, serialized);
      }
    } else {
      if (Platform.OS === "web") {
        if (typeof window !== "undefined" && window.localStorage) {
          window.localStorage.removeItem(STORAGE_KEY);
        }
      } else {
        await SecureStore.deleteItemAsync(STORAGE_KEY);
      }
    }
  } catch (err) {
    console.warn("Auth storage error:", err);
  }
}

async function loadSessionFromStorage(): Promise<UserSession | null> {
  try {
    let serialized: string | null = null;
    if (Platform.OS === "web") {
      if (typeof window !== "undefined" && window.localStorage) {
        serialized = window.localStorage.getItem(STORAGE_KEY);
      }
    } else {
      serialized = await SecureStore.getItemAsync(STORAGE_KEY);
    }
    if (serialized) {
      return JSON.parse(serialized);
    }
  } catch (err) {
    console.warn("Auth load error:", err);
  }
  return null;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<UserSession | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Load local session on startup only — no network calls in standalone mode
  useEffect(() => {
    loadSessionFromStorage()
      .then((stored) => {
        if (stored) {
          setSession(stored);
        }
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, []);

  const signIn = async (credentials: { email: string; password?: string }) => {
    const rawEmail = credentials.email.trim();
    if (!rawEmail) {
      return { success: false, error: "Please provide an email address." };
    }

    const namePrefix = rawEmail.split("@")[0] || "User";
    const displayName = namePrefix.charAt(0).toUpperCase() + namePrefix.slice(1);

    const newSession: UserSession = {
      user: {
        id: `usr_${Date.now()}`,
        name: displayName,
        email: rawEmail,
        image: null,
      },
    };

    setSession(newSession);
    await saveSessionToStorage(newSession);

    return { success: true };
  };

  const signUp = async (data: { name: string; email: string; password?: string; username?: string }) => {
    const newSession: UserSession = {
      user: {
        id: `usr_${Date.now()}`,
        name: data.name || data.username || "Lit Member",
        email: data.email,
        image: null,
      },
    };

    setSession(newSession);
    await saveSessionToStorage(newSession);

    return { success: true };
  };

  const socialSignIn = async (provider: "google" | "apple") => {
    const newSession: UserSession = {
      user: {
        id: `${provider}_${Date.now()}`,
        name: provider === "google" ? "Google Member" : "Apple Member",
        email: provider === "google" ? "user@gmail.com" : "user@privaterelay.appleid.com",
        image: null,
      },
    };

    setSession(newSession);
    await saveSessionToStorage(newSession);
    return { success: true };
  };

  const signOut = async () => {
    setSession(null);
    await saveSessionToStorage(null);
  };

  return (
    <AuthContext.Provider
      value={{
        session,
        isLoading,
        signIn,
        signUp,
        socialSignIn,
        signOut,
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
