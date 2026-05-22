import { View, Text } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

export default function ProfileScreen() {
  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top"]}>
      <View className="px-5 pt-4">
        <Text className="text-ink text-3xl font-semibold">Profile</Text>
        <Text className="text-ink-muted text-base mt-1">
          Your goals and preferences.
        </Text>
      </View>
      <View className="flex-1 items-center justify-center px-5">
        <Text className="text-ink-dim text-base text-center">
          Auth and onboarding land in the next todo.
        </Text>
      </View>
    </SafeAreaView>
  );
}
