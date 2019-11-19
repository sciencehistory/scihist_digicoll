const { environment } = require('@rails/webpacker')

environment.config.externals = {
  jquery: 'jQuery'
}

// Default max sizes for getting warned are ~260000. This isn't bit enough
// for our application entry point, mainly because of OpenSeadragon which is
// ~130000 all by itself. We increase to 400000 for now; although we could
// try to use techniques to reduce this, this is still probalby smaller than it
// was in chf_sufia sprockets only.
environment.config.performance = {
  maxEntrypointSize: 400000,
  maxAssetSize: 400000
}

module.exports = environment
