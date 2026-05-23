# Fresh machine setup

Step-by-step guide for cloning this repo onto a new computer and getting to a running app + database. Targets macOS, Windows (via WSL2), and Linux.

If you're already familiar with the stack, the short version is at the bottom — [TL;DR](#tldr).

---

## 1. Install prerequisites

| Tool | Version | Why | Where |
| --- | --- | --- | --- |
| **Node.js** | 20 LTS or 22 LTS | runs Metro / Expo CLI | [nvm](https://github.com/nvm-sh/nvm) (Mac/Linux/WSL) or [fnm](https://github.com/Schniz/fnm) — **don't use system apt-npm** |
| **Git** | 2.30+ | clone the repo | Pre-installed on Mac/Linux; `winget install Git.Git` on Windows |
| **Docker Desktop** | latest | runs Supabase locally | <https://www.docker.com/products/docker-desktop/> |
| **Supabase CLI** | matches package.json | DB migrations / local stack | shipped as devDep, used via `./node_modules/.bin/supabase` |
| **Xcode** (Mac only) | 15+ | iOS Simulator | App Store |
| **Android Studio** (any OS) | latest | Android emulator (optional) | <https://developer.android.com/studio> |
| **Expo Go** (phone) | latest | preview on a physical phone | App Store / Play Store |

### Node via nvm (recommended)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# restart your shell, then:
nvm install 20
nvm use 20
node --version    # should print v20.x
npm --version     # should print 10.x
```

> **Why not apt-npm**: on Ubuntu / WSL2 the apt-shipped `npm` is missing internal modules (`semver`, `@npmcli/config`) and every `npm` command except `install` crashes. nvm sidesteps the entire mess.

### Docker Desktop on Windows / WSL2

1. Install Docker Desktop.
2. Open **Settings → Resources → WSL Integration**.
3. Enable both "Enable integration with my default WSL distro" and the toggle for your specific Ubuntu distro.
4. Apply & restart.
5. Verify from inside WSL: `docker info | head -5` should print `Server: Docker Desktop` within ~5 seconds.

> If you have an old apt-installed Docker engine alongside Docker Desktop (`which -a docker` shows `/usr/bin/docker` separately from `/mnt/c/Program Files/Docker/...`), remove the apt one first: `sudo apt remove --purge docker.io docker-ce docker-ce-cli containerd.io && sudo apt autoremove`.

---

## 2. Clone the repo

```bash
git clone <your-repo-url> ai-kitchen-calorie-react-native-app
cd ai-kitchen-calorie-react-native-app
```

---

## 3. Install dependencies

```bash
npm install
```

Expect ~1000 packages and several deprecation warnings — all from inside Expo's tooling, ignore them. **Do not run `npm audit fix --force`** — it'll break the dependency graph.

If install fails with `(0 bytes)` / SHA512 integrity errors (typically after a system crash), wipe and retry:

```bash
rm -rf node_modules package-lock.json ~/.npm/_cacache
npm install
```

---

## 4. Configure environment variables

```bash
cp .env.example .env
```

For local dev you only need the two Supabase keys filled in. The rest can stay as placeholders (Sentry, PostHog, RevenueCat are no-ops when keys are missing — see [lib/observability.ts](../lib/observability.ts) and [lib/env.ts](../lib/env.ts)).

We'll fill the Supabase values in the next step once the local stack is running.

---

## 5. Start local Supabase

Make sure Docker Desktop is running, then:

```bash
./node_modules/.bin/supabase start
```

**First run takes 2–6 minutes** while Docker pulls ~2 GB of images (Postgres, GoTrue/Auth, Realtime, Storage, Studio, Edge Runtime, Kong, Inbucket). Subsequent starts are 30–60 seconds.

### If you hit ECR Public rate-limits

The error looks like:

```
failed to display json stream: toomanyrequests: Rate exceeded
```

Just retry — Docker caches every image layer that finishes downloading, so each retry only pulls what's missing. Usually finishes in 2–4 attempts.

### When it succeeds

You'll see a block like:

```
         API URL: http://127.0.0.1:54321
      Studio URL: http://127.0.0.1:54323
        anon key: eyJhbGciOiJIUzI1NiI...
service_role key: eyJhbGciOiJIUzI1NiI...
```

> You can reprint this anytime with `./node_modules/.bin/supabase status`.

Copy the **API URL** and **anon key** into `.env`:

```env
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiI...
```

> ⚠️ Use the **anon** key, never `service_role` — the latter bypasses RLS and must never ship in client code.

### Verify the DB is healthy

```bash
curl -s "http://127.0.0.1:54321/rest/v1/foods?select=name&limit=3" \
  -H "apikey: <paste anon key here>"
```

Should print 3 seed foods (egg, Greek yogurt, banana, etc.). If you get an empty array, the seed didn't apply — run `./node_modules/.bin/supabase db reset` to re-apply migrations + seed.

You can also browse the local Studio UI at <http://127.0.0.1:54323>.

---

## 6. Run the app

```bash
npm start
```

You'll see a QR code and a dev menu. From there:

- **`w`** — opens in your browser. Fastest sanity check; most UI works.
- **`i`** — opens iOS Simulator (Mac only).
- **`a`** — opens Android emulator (requires Android Studio + an emulator running).
- **Scan the QR with Expo Go on your phone** — for real device testing.

### Physical-phone gotcha

If you scan the QR with Expo Go on your phone, the phone resolves `http://127.0.0.1:54321` to *itself*, not your dev machine. You need to use your dev machine's LAN IP in `.env`:

```bash
# Linux / WSL2:
ip route get 1 | awk '{print $7;exit}'
# macOS:
ipconfig getifaddr en0
# Windows (in PowerShell):
ipconfig | findstr IPv4
```

Then edit `.env`:

```env
EXPO_PUBLIC_SUPABASE_URL=http://192.168.X.X:54321
```

And restart Metro (press `r` in the Expo CLI, or kill + `npm start`).

> Simulators (iOS / Android) run on the host, so `127.0.0.1` works fine for them.

---

## 7. Verify everything

You should now see:

- Metro logs print "Logs for your project will appear below" with no errors.
- The app boots to three tabs: **Today**, **Recipes**, **Profile**.
- The Today screen shows placeholder cards (real data lands in later todos).

If anything errors out, the first place to look is [STATUS.md → Gotchas](./STATUS.md#gotchas-hit-on-the-previous-machine-avoid-these-on-the-new-one) which catalogs the known foot-guns.

---

## 8. Useful day-to-day commands

| Command | Does |
| --- | --- |
| `npm start` | Metro / Expo dev server |
| `npm run ios` / `npm run android` | open simulator/emulator |
| `./node_modules/.bin/supabase status` | reprint local URLs + keys |
| `./node_modules/.bin/supabase db reset` | wipe local DB and re-apply migrations + seed |
| `./node_modules/.bin/supabase db diff` | what's drifted from migrations |
| `./node_modules/.bin/supabase functions serve` | run Edge Functions locally |
| `./node_modules/.bin/tsc --noEmit` | TypeScript check (use this if `npm run typecheck` fails because of system-npm issues) |
| `./node_modules/.bin/supabase stop` | shut down the local stack |

---

## TL;DR

```bash
# Prereqs: Node 20 (via nvm), Docker Desktop running, git
git clone <repo-url> ai-kitchen-calorie-react-native-app
cd ai-kitchen-calorie-react-native-app
npm install
cp .env.example .env
./node_modules/.bin/supabase start          # wait 2-6 min on first run; retry on ECR rate-limit
# paste API URL + anon key from `supabase status` into .env
npm start                                    # press `w` for browser or scan QR for Expo Go
```

If it all worked, head to [STATUS.md](./STATUS.md) for what to build next.
