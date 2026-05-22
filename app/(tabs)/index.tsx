import { ScrollView, View, Text } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

export default function TodayScreen() {
  return (
    <SafeAreaView className="flex-1 bg-bg" edges={["top"]}>
      <ScrollView
        contentContainerClassName="px-5 pb-12"
        showsVerticalScrollIndicator={false}
      >
        <View className="pt-4 pb-6">
          <Text className="text-ink-muted text-base">Good morning</Text>
          <Text className="text-ink text-3xl font-semibold mt-1">
            How's your day going?
          </Text>
        </View>

        {/* KCal summary card - skeleton */}
        <View className="bg-bg-card rounded-3xl p-6 mb-4">
          <Text className="text-ink-muted text-sm">Calories</Text>
          <View className="flex-row items-baseline mt-2">
            <Text className="text-ink text-5xl font-bold">--</Text>
            <Text className="text-ink-muted text-lg ml-2">/ -- kcal</Text>
          </View>
          <Text className="text-ink-dim text-sm mt-2">
            Sign in to start tracking.
          </Text>
        </View>

        {/* Macro bars - skeleton */}
        <View className="bg-bg-card rounded-3xl p-6 mb-4">
          {(["Protein", "Carbs", "Fat"] as const).map((label) => (
            <View key={label} className="mb-3 last:mb-0">
              <View className="flex-row justify-between mb-1">
                <Text className="text-ink-dim text-sm">{label}</Text>
                <Text className="text-ink-muted text-sm">-- / -- g</Text>
              </View>
              <View className="h-2 bg-bg-soft rounded-full overflow-hidden">
                <View className="h-full bg-brand w-0" />
              </View>
            </View>
          ))}
        </View>

        {/* Today's notes - placeholder for nudges */}
        <View className="bg-bg-card rounded-3xl p-6 mb-4">
          <Text className="text-ink-muted text-sm mb-2">Today's notes</Text>
          <Text className="text-ink-dim text-base">
            Your AI coach will leave gentle suggestions here as you log meals.
          </Text>
        </View>

        {/* Meals - placeholder */}
        <View className="bg-bg-card rounded-3xl p-6">
          <Text className="text-ink-muted text-sm mb-2">Meals</Text>
          <Text className="text-ink-dim text-base">No meals logged yet.</Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
