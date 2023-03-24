RT uses CKEditor as its WYSIWYG text editor. We build a customized download, then further customize it to get RT what it needs. This README explains how to get the right version of CKEditor and prepare it for use by RT.

1. Download CKEditor 4: https://ckeditor.com/cke4/builder

    * Click the "Upload build-config.js" button
    * Upload the build-config.js file found in devel/third-party/ckeditor-4.20.1 (or whatever version happens to be in devel/third-party/)
    * Check the "I agree..." checkbox at the bottom of the page
    * Click the "Download CKEditor..." button.

2. Install the updated version

    * Unzip the CKEditor archive you downloaded
    * Remove SECURITY.md and bender-runner.config.json from the extracted zip directory
    * mkdir devel/third-party/ckeditor-4.xx.xx
    * Copy README.md, LICENSE.md, CHANGES.md, build-config.js from the zip directory to devel/third-party/ckeditor-4.xx.xx
    * Copy the remainder of the zip contents to share/static/RichText/
    * Remove the old version of CKEditor from devel/third-party/:

      $ rm -rf devel/third-party/ckeditor-4.20.1 # or whatever the version in devel/third-party/ happens to be

3. Further customization

    * Remove the pbckcode plugin:

      $ rm -rf share/static/RichText/plugins/pbckcode

    * Update content.css via the following patch:

--- share/static/RichText/contents.css	2022-12-23 13:19:13.000000000 -0600
+++ /Users/jason/Downloads/contents.css	2022-12-29 09:42:05.000000000 -0600
@@ -14,7 +14,7 @@
 	color: #333;
 
 	/* Remove the background color to make it transparent. */
-	background-color: #fff;
+	background-color: transparent;
 
 	margin: 20px;
 }

    * Reset share/static/RichText/config.js from git. We have a customized version and
      the default version will get copied over in the previous steps.
    * Update CKEditor version in devel/third-party/README
    * Remove samples and docs:

      $ rm -rf skins/bootstrapck/sample
      $ rm -rf plugins/confighelper/docs/
      $ rm -rf plugins/ccmsconfighelper/docs
