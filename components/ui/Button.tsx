import { Pressable, Text, ActivityIndicator } from "react-native";
import type { PressableProps } from "react-native";

type Variant = "primary" | "secondary" | "ghost";

type Props = Omit<PressableProps, "children"> & {
  label: string;
  variant?: Variant;
  loading?: boolean;
};

const variants: Record<Variant, { container: string; text: string }> = {
  primary: {
    container: "bg-brand active:bg-brand-dim",
    text: "text-bg font-semibold",
  },
  secondary: {
    container: "bg-bg-card active:bg-bg-soft border border-bg-soft",
    text: "text-ink font-semibold",
  },
  ghost: {
    container: "bg-transparent active:bg-bg-soft",
    text: "text-ink-dim font-medium",
  },
};

export function Button({
  label,
  variant = "primary",
  loading,
  disabled,
  className = "",
  ...rest
}: Props) {
  const v = variants[variant];
  return (
    <Pressable
      disabled={disabled || loading}
      className={`px-5 py-4 rounded-2xl items-center justify-center ${v.container} ${disabled || loading ? "opacity-60" : ""} ${className}`}
      {...rest}
    >
      {loading ? (
        <ActivityIndicator color={variant === "primary" ? "#0F172A" : "#F8FAFC"} />
      ) : (
        <Text className={`text-base ${v.text}`}>{label}</Text>
      )}
    </Pressable>
  );
}
