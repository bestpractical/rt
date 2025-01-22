#!/usr/bin/env node

/* Based on the CKEditor build tool:
   https://github.com/ckeditor/ckeditor5/blob/master/scripts/nim/build-ckeditor5.mjs  */

import webpack from 'webpack';
import chalk from 'chalk';
import config from './webpack.config.cjs';

(async () => {
  try {
    console.log(chalk.cyan('Building CKEditor with inline styles...'));
    
    const compiler = webpack(config);
    await new Promise((resolve, reject) => {
      compiler.run((err, stats) => {
        if (err || stats.hasErrors()) {
          console.error(chalk.red('Build failed:'), stats.toString({ all: false, errors: true }));
          return reject(err || new Error(stats.toString({ all: false, errors: true })));
        }

        console.log(
          stats.toString({
            colors: true,
            chunks: false,
            modules: false,
          })
        );
        console.log(chalk.green('Build completed successfully!'));
        resolve();
      });
    });
  } catch (err) {
    console.error(chalk.red('Build process encountered an error:'), err);
  }
})();
