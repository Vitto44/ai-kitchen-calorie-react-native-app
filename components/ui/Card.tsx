import { View } from "react-native";
import type { ReactNode } from "react";

type Props = {
  children: ReactNode;
  className?: string;
};

export function Card({ children, className = "" }: Props) {
  return (
    <View className={`bg-bg-card rounded-3xl p-6 ${className}`}>
      {children}
    </View>
  );
}
