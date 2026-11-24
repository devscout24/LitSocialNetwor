import { Button, FieldError, Input, Label, Spinner, Surface, TextField } from "heroui-native";
import { useState } from "react";
import { Text, View } from "react-native";

import { useAppAuth } from "@/lib/auth-state";

export function SignUp() {
  const { signUp } = useAppAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handlePress() {
    setIsLoading(true);
    setError(null);

    const result = await signUp({
      name,
      email,
      password,
    });

    setIsLoading(false);

    if (!result.success) {
      setError(result.error || "Failed to sign up");
      return;
    }

    setName("");
    setEmail("");
    setPassword("");
  }

  return (
    <Surface variant="secondary" className="p-4 rounded-lg">
      <Text className="text-foreground font-medium mb-4">Create Account</Text>

      <FieldError isInvalid={!!error} className="mb-3">
        {error}
      </FieldError>

      <View className="gap-3">
        <TextField>
          <Label>Name</Label>
          <Input value={name} onChangeText={setName} placeholder="John Doe" />
        </TextField>

        <TextField>
          <Label>Email</Label>
          <Input
            value={email}
            onChangeText={setEmail}
            placeholder="email@example.com"
            keyboardType="email-address"
            autoCapitalize="none"
          />
        </TextField>

        <TextField>
          <Label>Password</Label>
          <Input
            value={password}
            onChangeText={setPassword}
            placeholder="••••••••"
            secureTextEntry
          />
        </TextField>

        <Button onPress={handlePress} isDisabled={isLoading} className="mt-1">
          {isLoading ? (
            <Spinner size="sm" color="default" />
          ) : (
            <Button.Label>Create Account</Button.Label>
          )}
        </Button>
      </View>
    </Surface>
  );
}
