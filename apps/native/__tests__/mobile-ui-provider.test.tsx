/// <reference types="jest" />

import type { ReactNode } from "react";

import { render } from "@testing-library/react-native";
import { Text } from "react-native";

import { MobileUIProvider } from "@/components/mobile-ui-provider";

test("renders children inside the mobile provider", async () => {
  const screen = await render(
    <MobileUIProvider>
      <Text>Mobile ready</Text>
    </MobileUIProvider>,
  );

  expect(screen.getByText("Mobile ready")).toBeTruthy();
});
