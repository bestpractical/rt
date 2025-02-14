const path = require('path');
const { CKEditorTranslationsPlugin } = require('@ckeditor/ckeditor5-dev-translations');
const { styles } = require('@ckeditor/ckeditor5-dev-utils');

module.exports = {
  mode: 'production',
  entry: './src/index.ts', // Your CKEditor entry point
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'ckeditor.js', // Unified output
    library: 'CKEDITOR',
    libraryTarget: 'umd',
  },
  resolve: {
    extensions: ['.ts', '.js'],
  },
  module: {
    rules: [
      {
        test: /\.svg$/,
        use: ['raw-loader'],
      },
      {
        test: /\.ts$/,
        use: 'ts-loader',
      },
      {
        test: /\.css$/,
        use: [
          {
            loader: 'style-loader',
            options: {
              injectType: 'singletonStyleTag', // Inlines all styles into a single <style> tag
              attributes: { 'data-cke': true },
            },
          },
          'css-loader',
          {
            loader: 'postcss-loader',
            options: {
              postcssOptions: styles.getPostCssConfig({
                themeImporter: {
                  themePath: require.resolve('@ckeditor/ckeditor5-theme-lark'),
                },
                minify: true,
              }),
            },
          },
        ],
      },
    ],
  },
  plugins: [
    new CKEditorTranslationsPlugin({
      language: 'en',
      additionalLanguages: 'all',
      outputDirectory: 'translations',
    }),
  ],
};
