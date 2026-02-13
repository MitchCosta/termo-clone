import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./src/components/**/*.{ts,tsx}", "./src/app/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        "tile-absent": "#3a3a3c",
        "tile-present": "#b59f3b",
        "tile-correct": "#538d4e"
      }
    }
  },
  plugins: []
};
export default config;
