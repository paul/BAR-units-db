import build from "./config/esbuild.defaults.js"
import sveltePlugin from "esbuild-svelte"

/**
 * @typedef { import("esbuild").BuildOptions } BuildOptions
 * @type {BuildOptions}
 */
const esbuildOptions = {
  publicPath: "/BAR-units-db",
  plugins: [
    sveltePlugin({
      compilerOptions: { css: "injected" },
    }),
  ],
  mainFields: ["svelte", "browser", "module", "main"],
  conditions: ["svelte", "browser"],
  globOptions: {
    excludeFilter: /\.(dsd|lit)\.css$/
  }
}

build(esbuildOptions)
