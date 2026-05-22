import * as Sentry from "sentry-expo";
import PostHog from "posthog-react-native";
import { env, isProd } from "./env";

type EventProps = Record<string, string | number | boolean | null>;

let posthogInstance: PostHog | null = null;

export function initObservability() {
  if (env.EXPO_PUBLIC_SENTRY_DSN) {
    Sentry.init({
      dsn: env.EXPO_PUBLIC_SENTRY_DSN,
      enableInExpoDevelopment: false,
      debug: !isProd,
      tracesSampleRate: isProd ? 0.1 : 1.0,
    });
  }

  if (env.EXPO_PUBLIC_POSTHOG_API_KEY && isProd) {
    posthogInstance = new PostHog(env.EXPO_PUBLIC_POSTHOG_API_KEY, {
      host: env.EXPO_PUBLIC_POSTHOG_HOST ?? "https://us.i.posthog.com",
      captureNativeAppLifecycleEvents: true,
    });
  }
}

export function track(event: string, properties?: EventProps) {
  posthogInstance?.capture(event, properties);
}

export function identify(userId: string, properties?: EventProps) {
  posthogInstance?.identify(userId, properties);
}

export function captureError(error: unknown, context?: Record<string, unknown>) {
  if (env.EXPO_PUBLIC_SENTRY_DSN) {
    Sentry.Native.captureException(error, { extra: context });
  } else {
    console.error("[error]", error, context);
  }
}
