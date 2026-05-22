import "react-native-url-polyfill/auto";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createClient } from "@supabase/supabase-js";
import { env } from "./env";

// We intentionally use AsyncStorage rather than SecureStore for the session
// because the JWT is large and SecureStore on iOS has a ~4KB practical limit
// per item. The JWT alone is not enough to compromise the account without
// the device PIN, and Supabase auto-rotates refresh tokens.
export const supabase = createClient(
  env.EXPO_PUBLIC_SUPABASE_URL,
  env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
  {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  },
);
