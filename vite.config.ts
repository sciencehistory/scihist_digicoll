import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import { brotliCompressSync } from "zlib";
import gzipPlugin from "rollup-plugin-gzip";
import sassGlobImports from 'vite-plugin-sass-glob-import';
import { resolve } from 'path'


let vitePlugins = [
  RubyPlugin(),
  sassGlobImports()
]

// gzip and brotli plugin from https://github.com/ElMassimo/vite_ruby/discussions/101#discussioncomment-1019222
// and https://vite-ruby.netlify.app/guide/deployment.html#compressing-assets-%F0%9F%93%A6
//
// if we create .gz alternatives, Rails automatically will serve gzip'd content,
// in our heroku setup where the Rails app is directly serving assets (cached by CDN)
//
// https://github.com/ElMassimo/vite_ruby/discussions/281
//
// But in development autoBuild mode, it slows things down, and doesn't help, so not there.
if (! (process.env.VITE_RUBY_AUTO_BUILD == "true")) {
  vitePlugins = vitePlugins.concat([
    // Create gzip copies of relevant assets
    gzipPlugin(),
    // Create brotli copies of relevant assets
    gzipPlugin({
      customCompression: (content) => brotliCompressSync(Buffer.from(content)),
      fileName: ".br",
    })
  ])
}

export default defineConfig({
  // enable sass sourcemaps -- vite supports sass sourcemaps with dev server only
  css: {
    devSourcemap: true
  },
  plugins: vitePlugins,
  // video.js is REALLY BIG, telling vite/rollup to chunk it as it's own
  // JS file may improve performance, or at least reduce warnings about big
  // files -- even if it's still statically imported at page load.
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          "video.js": ['video.js']
        }
      }
    },
    // Seems necessary to get sourceMaps in dev autoBuild, which are kind of
    // important for being able to debug. https://github.com/ElMassimo/vite_ruby/discussions/285
    sourcemap: true
  },
  resolve: {
    alias: {
      "@stylesheets": resolve(__dirname, 'app/frontend/stylesheets')
    }
  }
})
