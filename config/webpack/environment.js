const { environment } = require('@rails/webpacker')

// Uppy currently still being loaded via a script tag to CDN outside of webpacker,
// with this we can still `import Uppy from 'uppy';` in webpacker sources to use it. `
environment.config.externals = {
  uppy: 'Uppy'
}

module.exports = environment
