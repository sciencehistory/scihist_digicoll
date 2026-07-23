import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import { compression } from 'vite-plugin-compression2';
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
    compression(),
    compression({ algorithm: 'brotliCompress' })
  ])
}

export default defineConfig({
  // enable sass sourcemaps -- vite supports sass sourcemaps with dev server only
  css: {
    devSourcemap: true,
    preprocessorOptions: {
      scss: {
        // Bootstrap 5.3.x still uses @import and legacy color functions that
        // modern Dart Sass deprecates; silence the dependency noise until we
        // move to Bootstrap 6. quietDeps hides warnings from node_modules;
        // silenceDeprecations covers the ones that fire from our own
        // `@import "bootstrap"` entry points.
        quietDeps: true,
        silenceDeprecations: ['import', 'global-builtin', 'color-functions']
      }
    }
  },
  plugins: vitePlugins,
  // video.js is REALLY BIG, telling vite/rollup to chunk it as it's own
  // JS file may improve performance, or at least reduce warnings about big
  // files -- even if it's still statically imported at page load.
  build: {
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          if (id.includes('node_modules/video.js')) return 'video.js';
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
