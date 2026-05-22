import { Redirect } from "expo-router";

// Entry point. Auth + onboarding completion checks will be added in the
// auth_onboarding todo; for now route everyone into the main tabs.
export default function Index() {
  return <Redirect href="/(tabs)" />;
}
