/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        bg: {
          DEFAULT: "#0F172A",
          soft: "#1E293B",
          card: "#1F2937",
        },
        ink: {
          DEFAULT: "#F8FAFC",
          dim: "#CBD5E1",
          muted: "#94A3B8",
        },
        brand: {
          DEFAULT: "#22C55E",
          dim: "#16A34A",
          soft: "#86EFAC",
        },
        warn: "#F59E0B",
        bad: "#EF4444",
      },
      fontFamily: {
        sans: ["System"],
      },
    },
  },
  plugins: [],
};
