# Status

> Last updated: 2026-05-23. See [PLAN.md](./PLAN.md) for the full design plan and [SETUP.md](./SETUP.md) for fresh-machine setup.

## Progress at a glance

| # | Todo | Status |
| --- | --- | --- |
| 1 | Scaffold Expo + TypeScript + Expo Router + NativeWind, EAS, Sentry/PostHog | ✅ done |
| 2 | Supabase project: schema + RLS + `v_daily_intake` view | ✅ done |
| 3 | Auth (email + Apple + Google) and onboarding wizard with Mifflin-St Jeor calc | ⏭️ **next** |
| 4 | Food search + USDA/OFF seeding + barcode + manual log + quick-log | pending |
| 5 | Today screen: kcal counter, macro bars, meals list, HealthKit/Google Fit read | pending |
| 6 | Nutrition label OCR (`gpt-4o-mini` Vision Edge Function + camera UI) | pending |
| 7 | AI nudges engine (rules + `gpt-4o-mini` wording + Today's notes UI) | pending |
| 8 | Recipes (seed 8–10 + browse + detail screens) | pending |
| 9 | Voice cooking (turn-by-turn `voice-turn` Edge Function + expo-av client + tools) | pending |
| 10 | RevenueCat paywall + tier enforcement + Sentry/PostHog wiring | pending |
| 11 | TestFlight + Play Internal Testing + store submission | pending |

## What's in the repo right now

- **App shell**: Expo Router with three tabs (`Today` / `Recipes` / `Profile`) and a modal `cook/[recipeId]` route. All placeholders so far — see [`app/`](../app/).
- **UI primitives**: `Button` + `Card` in [`components/ui/`](../components/ui/) with a NativeWind dark palette (`bg`, `ink`, `brand`, `warn`, `bad`).
- **Lib helpers**: [`lib/env.ts`](../lib/env.ts) (Zod-validated env vars), [`lib/supabase.ts`](../lib/supabase.ts) (AsyncStorage-backed client), [`lib/observability.ts`](../lib/observability.ts) (Sentry + PostHog).
- **Database**: full schema in [`supabase/migrations/0001_init.sql`](../supabase/migrations/0001_init.sql) — 10 tables, 12 enums, RLS on everything, auto-profile-on-signup trigger, `v_daily_intake` view, trigram + barcode indexes. 8 starter foods seeded in [`supabase/seed.sql`](../supabase/seed.sql) for local dev.
- **Tooling**: EAS config ([`eas.json`](../eas.json)), Tailwind/NativeWind, Prettier with Tailwind class sorting, TypeScript strict mode with `noUncheckedIndexedAccess`, path aliases (`@lib/*`, `@components/*`, `@app/*`).

## What's still placeholder

- The three tab screens render skeleton text only — no real data.
- No auth — the entry redirect in [`app/index.tsx`](../app/index.tsx) sends straight to tabs.
- No onboarding flow yet — [`app/(onboarding)/_layout.tsx`](../app/%28onboarding%29/_layout.tsx) is an empty Stack.
- No icons / splash / favicon in [`assets/`](../assets/) — Expo will warn but won't fail.

## Decision log (so the new machine doesn't re-litigate)

These are the architectural calls already made. See [PLAN.md → Key decisions made along the way](./PLAN.md#key-decisions-made-along-the-way) for full rationale.

- **Voice = turn-by-turn STT + LLM + TTS**, not OpenAI Realtime. 5–10× cheaper, simpler. Realtime "Live Mode" reserved as a post-MVP Pro tier upgrade.
- **Backend = Supabase** (Postgres + Auth + Storage + Edge Functions). Not Firebase, not custom Node.
- **Positioning = nutrition newcomers**, competitors are Noom + Cal AI (not MyFitnessPal). UI is approachable but numbers stay visible — no "Simple mode" toggle.
- **AI surfaces = nudges + voice cooking only at MVP.** No "Ask anything" chat tab.
- **Pricing = $9.99 Premium / $14.99 Pro.** Free tier gets 5 voice sessions/month.

## Gotchas hit on the previous machine (avoid these on the new one)

1. **WSL2 + Docker Desktop** — make sure Docker Desktop is **up-to-date** (the v24/2023 bundled client gave API-version 500s on every call) and that **WSL integration is explicitly enabled** for your distro under *Docker Desktop → Settings → Resources → WSL Integration*.
2. **Conflicting apt-installed Docker** — if `which -a docker` shows `/usr/bin/docker` separately from `/mnt/c/Program Files/...`, remove the apt one (`sudo apt remove docker.io docker-ce docker-ce-cli`) before doing anything.
3. **Empty `~/.expo/state.json`** — known Expo CLI bug after a killed run. Fix: `echo '{}' > ~/.expo/state.json`.
4. **System `npm` from apt is broken** — `/usr/share/nodejs/npm` is missing internal modules. Use `nvm` (or `fnm`) instead. `nvm install 20 && nvm use 20`.
5. **`react-native-css-interop` cache files at 0 bytes** — leftover from a crashed install. Fix: `rm -rf node_modules package-lock.json ~/.npm/_cacache && npm install`.
6. **ECR Public rate-limits during `supabase start`** — first-time pulls of all 8 Supabase images can trip the 1 pull/sec anonymous limit. Just retry a few times; images already pulled are cached.
7. **PC crash mid-install** corrupts npm's content-addressed cache. Same fix as #5. If it keeps happening, switch to `pnpm` (better atomic writes) or save a `tar czf node_modules-snapshot.tgz node_modules` after a known-good install.
8. **Phone testing** — `127.0.0.1` in `.env` only works for browser preview / simulator. For a physical phone via Expo Go, swap it for your LAN IP: `ip route get 1 | awk '{print $7;exit}'`.

## Next session plan

When you sit down on the new machine:

1. **Follow [SETUP.md](./SETUP.md)** to clone, install, start Supabase, fill `.env`.
2. **Run `npm start`** to confirm the three tabs render.
3. **Open a fresh chat with the AI assistant** and paste:
   > Continue implementing the AI Kitchen MVP. Status doc is at `docs/STATUS.md`. The next todo is **auth + onboarding wizard** (Apple/Google/email sign-in + the plain-language profile wizard with Mifflin-St Jeor calc). Start there.
4. The assistant should read [PLAN.md](./PLAN.md), [STATUS.md](./STATUS.md), and the existing scaffold, then begin work.
