import { View, Text } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useLocalSearchParams } from "expo-router";

export default function CookScreen() {
  const { recipeId } = useLocalSearchParams<{ recipeId: string }>();
  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top"]}>
      <View className="px-5 pt-4">
        <Text className="text-ink-muted text-sm">Cooking</Text>
        <Text className="text-ink text-2xl font-semibold mt-1">
          Recipe {recipeId}
        </Text>
      </View>
      <View className="flex-1 items-center justify-center px-5">
        <Text className="text-ink-dim text-base text-center">
          Voice cooking lands in the voice_cooking todo (Week 4).
        </Text>
      </View>
    </SafeAreaView>
  );
}
