const { environment } = require('@rails/webpacker')

environment.config.externals = {
  jquery: 'jQuery'
}

module.exports = environment
