import { View, Text } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

export default function RecipesScreen() {
  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top"]}>
      <View className="px-5 pt-4">
        <Text className="text-ink text-3xl font-semibold">Recipes</Text>
        <Text className="text-ink-muted text-base mt-1">
          Pick one and cook with your AI coach.
        </Text>
      </View>
      <View className="flex-1 items-center justify-center px-5">
        <Text className="text-ink-dim text-base text-center">
          Recipes will appear here once the recipes todo is built.
        </Text>
      </View>
    </SafeAreaView>
  );
}
