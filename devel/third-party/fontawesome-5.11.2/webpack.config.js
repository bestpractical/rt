const BabelMinifyPlugin = require('babel-minify-webpack-plugin')
module.exports = {
    mode: 'production',
    entry: './index.js',
    output: {
      filename: './fontawesome.js'
    },
    optimization: {
      minimizer: [
        new BabelMinifyPlugin()
      ]
    }
}
