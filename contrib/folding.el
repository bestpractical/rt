;; @(#) folding.el -- A folding-editor-like minor mode.

;; Copyright (C) 1992-1997
;;           Jamie Lokier, All rights reserved.
;; Copyright (C) 1994-1999
;;           Jari Aalto, Anders Lindgren, Jack Repenning, All rights reserved.
;;
;; Author:      Jamie Lokier    <jamie@imbolc.ucc.ie>
;;              Jari Aalto      <jari.aalto@poboxes.com>
;;              Anders Lindgren <andersl@csd.uu.se>
;;              Jack Repenning  <jackr@informix.com>
;; Maintainer:  Jari Aalto      <jari.aalto@poboxes.com>
;;              Anders Lindgren <andersl@csd.uu.se>
;; Created:     1992
;; RCS version: $Revision$
;; Date:        $Date$
;; Keywords:    tools

;;{{{ GPL

;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 2 of the License, or (at your option)
;; any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;}}}
;;{{{ Introduction

;;; Commentary:

;; Preface
;;
;;      This package provides a minor mode, compatible with all major
;;      editing modes, for folding (hiding) parts of the edited text or
;;      program.
;;
;;      Folding mode handles a document as a tree, where each branch is
;;      bounded by special markers `{{{' and `}}}'.  A branch can be placed
;;      inside another branch, creating a complete hierarchical structure.
;;
;;      Folding mode can CLOSE a fold, leaving only the initial `{{{'
;;      and possibly a comment visible.
;;
;;      It can also ENTER a fold, which means that only the current fold
;;      will be visible, all text above `{{{' and below `}}}' will be
;;      invisible.
;;

;;}}}
;;{{{ Installation

;;  Installation
;;
;;      To install Folding mode, put this file (folding.el) on your
;;      Emacs-Lisp load path (or extend the load path to include the
;;      directory containing this file) and byte compile it.
;;
;;	The best way to install folding is the autolaod installation,
;;	so that folding is loaded into your emacs only when you turn on
;;	`folding-mode'. This statement speeds up loading your .emacs
;;
;;	    (autoload 'folding-mode "folding" "Folding mode" t)
;;
;;	But if you always use folding, then perhaps you want more traditional
;;	installation. Here Folding mode starts automatically when you
;;	load a folded file.
;;
;;          ;; (setq folding-default-keys-function
;;          ;;      'folding-bind-backward-compatible-keys)
;;
;;          (load "folding" 'nomessage 'noerror)
;;          (folding-mode-add-find-file-hook)
;;
;;      Folding now uses a keymap which conforms with the Emacs 19.29
;;      style.  The key bindings are the same as in previous versions of
;;      folding, but they are prefixed with "C-c@" instead of "C-c".
;;
;;      To use the old keyboard bindings, uncomment the lines in the
;;      the instalation example above. Also genally speaking: Define all
;;      variables before package uses it or sees them, and only then load it.

;;}}}
;;{{{ Documentation

;;
;;  Compatibility
;;
;;      Folding works natively in Unix Emacs versions
;;
;;          Emacs  19.28+  and NT Emacs  19.34+
;;          XEmacs 19.14+  and NT XEmacs 21.0+
;;
;;
;;  Compatibility: win32 Emacs
;;
;;      NOTE: folding version starting from 2.47 gets around this bug
;;      by using adviced kill/yank functions. The advice functions are
;;      only instantiated under problematic NT Emacs versions.
;;
;;      Windows NT/95 19.34-20.3.1 (i386-*-nt4.0) version contains a bug which
;;      affects using folding: reported by Trey Jackson
;;      <trey@cs.berkeley.edu>
;;
;;          If you kill folded area and yank it back, the ^M marks are
;;          removed for some reason.
;;
;;          Before kill
;;          {{{ fold...
;;
;;          After yank
;;          {{{ foldthat was the beginning of the foldand the end is near}}}
;;
;;  Tutorial
;;
;;      To start folding mode, give the command: `M-x' `folding-mode' `RET'
;;
;;      The mode line should contain the string "Fld" indicating that
;;      folding mode is activated.
;;
;;      When loading a document containing fold marks, Folding mode is
;;      automatically started and all folds are closed.  For example when
;;      loading my init file, only the following lines (plus a few lines
;;      of comments) are visible:
;;
;;          ;;{{{ General...
;;          ;;{{{ Keyboard...
;;          ;;{{{ Packages...
;;          ;;{{{ Major modes...
;;          ;;{{{ Minor modes...
;;          ;;{{{ Debug...
;;
;;      To enter a fold, use `C-c @ >'.  To show it without entering,
;;      use `C-c @ C-s', which produces this display:
;;
;;          ;;{{{ Minor modes
;;
;;          ;;{{{ Follow mode...
;;          ;;{{{ Font-lock mode...
;;          ;;{{{ Folding...
;;
;;          ;;}}}
;;
;;      To show everything, just as the file would look like if Folding
;;      mode hadn't been activated, give the command
;;      `M-x' `folding-open-buffer' `RET', normally bound to `C-c' `@' `C-o'.
;;      To close all folds and go to the top level, the command
;;      `folding-whole-buffer' could be used.
;;
;;  Mouse support
;;
;;      Folding mode V2.0 introduced mouse support.  Folds can be shown or
;;      hidden by simply clicking on a fold mark using mouse button 3.
;;      The mouse routines have been designed to call the original function
;;      bound to button 3 when the user didn't click on a fold mark.
;;
;;  The menu
;;
;;      A menu is placed in the "Tools" menu.  Should no Tools menu exist
;;      (Emacs 19.28) the menu will be placed in the menu bar.
;;
;;  ISearch
;;
;;      When searching using the incremental search (C-s) facilities, folds
;;      will be automagically entered and closed.
;;
;;  Problems
;;
;;     uneven fold marks
;;
;;      Oops, I just deleted some text, and a fold mark just happened to be
;;      deleted!  What should I do?  Trust me, you will eventually do this
;;      sometime. the easiest way is to open the buffer using
;;      `folding-open-buffer' (C-c @ C-o) and add the fold mark by hand.  To
;;      find mismatching fold marks, the package `occur' is useful.  The
;;      command:
;;
;;          M-x occur RET {{{\|}}} RET
;;
;;      will extract all lines containing folding marks and present them in
;;      a separate buffer.
;;
;;      Even though all folding marks are correct, Folding mode sometimes
;;      gets confused, especially when entering and leaving folds very
;;      often.  To get it back on track, press C-g a few times and give the
;;      command `folding-open-buffer' (C-c @ C-o).
;;
;;     Fold must have a label
;;
;;      When you make a fold, be sure to write some text for the name
;;	of the fold, otherwise you will have an error "extraneous fold mark...
;;      For example write:
;;
;;          {{{ Note
;;          }}}
;;
;;      instead of
;;
;;          {{{
;;          }}}
;;
;;     folding-whole-buffer doesn't fold whole buffer
;;
;;	If you call commands `folding-open-buffer' and `folding-whole-buffer'
;;	and notice that there are open fold sections in the buffer, then
;;	you have mismatch of folds somewhere. Run occur to check where
;;	is the extra open or colosing fold mark.
;;
;;  Folding and outline modes
;;
;;      Folding mode is not the same as Outline mode, a major and minor
;;      mode which is part of the Emacs distribution.  The two packages do,
;;      however, resemble each other very much.
;;
;;      The main differences between the two packages are:
;;
;;      o   Folding mode uses explicit marks, `{{{' and `}}}', to
;;          mark the beginning and the end of a branch.
;;          Outline, on the other other hand, tries to use already existing
;;          marks, like the `\section' string in a TeX document.
;;
;;      o   Outline mode has no end marker which means that it is impossible
;;          for text to follow a sub-branch.
;;
;;      o   Folding mode use the same markers for branches on all depths,
;;          Outline mode requires that marks should be longer the further,
;;          down in the tree you go, e.g `\chap', \section', `\subsection',
;;          `\subsubsection'.  This is needed to distinguish the next mark at
;;          the current or higher levels from a sub-branch, a problem caused
;;          by the lack of end-markers.
;;
;;      o   Folding mode has mouse support, you can navigate through a folded
;;          document by clicking on fold marks.  (The XEmacs version of
;;          Outline mode has mouse support.)
;;
;;      o   The Isearch facilities of Folding is capable of automatically open
;;          folds.  Under Outline, the isearch is practically useless unless
;;          the entire document is opened prior to use.
;;
;;      In conclusion, Outline mode is useful when the document being
;;      edited contains natural markers, like LaTeX.  When writing code
;;      natural markers are hard to find, except if you're happy with
;;      one function per fold (I'm not).
;;
;;  Personal reflections by Anders Lindgren
;;
;;      When writing this, version 2.0 of Folding mode is just about to be
;;      released.  The current version has proven itself stable during a
;;      six months beta testing period.  In other words: we haven't had
;;      time to touch the damn thing for quite some time.
;;
;;      Our plan was from the beginning to rewrite the entire package,
;;      including replacing the core of the program, written using Emacs 18
;;      technology (selective display), and replace it with modern
;;      equivalences, like overlays or text-properties for Emacs 19 and
;;      extents for XEmacs.
;;
;;      Unfortunately, this has not yet been done, even though we have
;;      implemented most other items on our to-do agenda.
;;
;;      It is not likely that any of us, in the near future, will find the
;;      time required to rewrite the core of the package.  Since the
;;      package, in it's current state, is much more powerful than the
;;      original, we have decided to make this intermediate release.

;;}}}

;;{{{ Customisation

;;  Customisation: general
;;
;;      The behaviour of Folding mode is controlled mainly by a set of
;;      Emacs Lisp variables.  This section will discuss the most useful
;;      ones, for more details please see the code.  The descriptions below
;;      assumes that you know a bit about how to use simple Emacs Lisp and
;;      knows how to edit ~/.emacs, your init file.
;;
;;  Customisation: hooks
;;
;;      The normal procedure when customising a package is to write a
;;      function doing the customisation.  The function is then added to
;;      a hook which is called at an appropriate time.  (Please see the
;;      example section below.)
;;
;;      The following hooks are available:
;;
;;      o   `folding-mode-hook'
;;           Called when folding mode is activated.
;;
;;      o   `<major mode>-folding-hook'
;;           Called when starting folding mode in a buffer with major
;;           mode set to <major mode>.  (e.g. When editing C code
;;           the hook `c-mode-folding-hook' is called.)
;;
;;      o   `folding-load-hook'
;;           Called when folding mode is loaded into Emacs.
;;
;;  Customisation: The Mouse
;;
;;      The variable `folding-behave-table' contains the actions which should
;;      be performed when the user clicks on an open fold, a closed fold etc.
;;      For example, if you prefer to `enter' a fold rather than `open' it
;;      you should rebind this variable.
;;
;;      The variable `folding-default-mouse-keys-function' contains the name
;;      of the function used to bind your mouse keys.  To use your own
;;      mouse bindings, create a function, say `my-folding-bind-mouse', and set
;;      this variable to it.
;;
;;  Customisation: Keymaps
;;
;;      When Emacs 19.29 was released, the keymap was
;;      divided into strict parts.  (This division existed before, but a lot
;;      of packages, even the ones delivered with Emacs, ignored them.)
;;
;;          C-c <letter>    -- Reserved for the users private keymap.
;;          C-c C-<letter>  -- Major mode.  (Some other keys are
;;                             reserved as well.)
;;          C-c <Punctuation Char> <Whatever>
;;                          -- Reserved for minor modes.
;;
;;      The reason why I choosed C-c@ as the default prefix is that it is used
;;      by outline-minor-mode.  I suspect that few people will try to use
;;      folding and outline at the same time.
;;
;;      However, I have made it possible to keep your old keybindings.  The
;;      variable `folding-default-keys-function' specifies which function should
;;      be called to bind the keys.  The plan is to define a selection of
;;      keybinding functions.  For example, we have one which tries to bind
;;      the keys in a way compatible to outline mode.
;;
;;      To use the old keybindings, add the following line to your init file:
;;
;;	    (setq folding-default-keys-function
;;		  'folding-bind-backward-compatible-keys)
;;
;;      To define keys similar to the keys used by Outline mode, use:
;;
;;	    (setq folding-default-keys-function
;;                'folding-bind-outline-compatible-keys)
;;
;;  Customisation: adding new major modes
;;
;;      To add fold marks for a new major mode, use the function
;;      `folding-add-to-marks-list'. Example:
;;
;;          (folding-add-to-marks-list 'c-mode "/* {{{ " "/* }}} */" " */" t)
;;          (folding-add-to-marks-list 'java-mode "// {{{ " "// }}}" nil t)
;;
;;  Customisation: ISearch
;;
;;      If you don't like the extension folding.el applies to isearch,
;;      set the variable `folding-isearch-install' to nil before loading
;;      this package.

;;}}}
;;{{{ Examples

;;  Example: personal setup
;;
;;      To define your own keybinding instead of using the standard ones,
;;      you can do like this:
;;
;;           (defconst folding-mode-prefix-key "\C-c")
;;           ;;
;;           (defconst folding-default-keys-function
;;               '(folding-bind-backward-compatible-keys))
;;           ;;
;;           (defconst folding-load-hook 'my-folding-load-hook)
;;
;;
;;           (defun my-folding-load-hook ()
;;             "Folding setup."
;;
;;             (folding-install)  ;; just to be sure
;;
;;             ;; ............................................... markers ...
;;
;;             ;;  Change text-mode fold marks. I ussually program my
;;             ;;  sh/perl/awk there, so use "#"
;;
;;             (defvar folding-mode-marks-alist nil)
;;
;;             (let* ((ptr (assq 'text-mode folding-mode-marks-alist)))
;;               (setcdr ptr (list "# {{{" "# }}}")))
;;
;;             ;; ............................................... bindings ...
;;
;;             ;;  Put `folding-whole-buffer' and `folding-open-buffer'
;;             ;;  close together.
;;
;;             (defvar folding-mode-prefix-map nil)
;;
;;             (define-key folding-mode-prefix-map "\C-w" nil)
;;             (define-key folding-mode-prefix-map "\C-s"
;;                         'folding-show-current-entry)
;;             (define-key folding-mode-prefix-map "\C-p"
;;                         'folding-whole-buffer)
;;             )
;;
;;  Example: changing default fold marks
;;
;;      In case you're not happy with the default folding marks, you
;;      can change them easily. Here is an example
;;
;;          (setq folding-load-hook 'my-folding-load-hook)
;;
;;          (defun my-folding-load-hook ()
;;            "Folding vars setup."
;;            (let* ((ptr (assq 'text-mode folding-mode-marks-alist)))
;;              (setcdr ptr (list "# {{{" "# }}}"))))
;;
;;
;;  Example: choosing different fold marks for mode
;;
;;	Suppose you sometimes want to use different fold marks for the major
;;	mode: eg. if to alaternate between "# {{{" and "{{{" in `text-mode'
;;	Call `M-x' `my-folding-text-mode-setup' to change the marks.
;;
;;            (defun my-folding-text-mode-setup (&optional use-custom-folding-marks)
;;            	(interactive
;;                (list (y-or-n-p "Use Custom fold marks now? ")))
;;            	(let* ((ptr (assq major-mode folding-mode-marks-alist))
;;            	       (default-begin "# {{{")
;;            	       (default-end   "# }}}")
;;            	       (begin "{{{")
;;            	       (end   "}}}")
;;            	       )
;;            	  (when (eq major-mode 'text-mode)
;;            	    (unless use-custom-folding-marks
;;            	      (setq  begin default-begin  end default-end)))
;;            	  (setcdr ptr (list begin end))
;;            	  (folding-set-marks begin end)))
;;
;;  Bugs: Lazy-shot.el conflict in XEmacs
;;
;;	[XEmacs 20.4 lazy-shot-mode]
;;	1998-05-28 Reported by Solofo Ramangalahy <solofo@mpi-sb.mpg.de>
;;
;;          % xemacs -q folding.el
;;          M-x eval-buffer
;;          M-x folding-mode
;;          M-x font-lock-mode
;;          M-x lazy-shot-mode
;;          C-s mouse
;;
;;      then search for mouse again and again. At some point you will see
;;      "Deleting extent" in the minibuffer and XEmacs freezes.
;;
;;      The strange point is that I have this bug only under solaris 2.5 sparc
;;      (binaries from ftp.xemacs.org) but not under solaris 2.6 x86. (XEmacs
;;      20.4, folding 2.35). I will try to access more machines to see if it's
;;      the same.
;;
;;      I suspect that the culprit is lazy-sho2t as it is beta, but maybe you
;;      will be able to describe the bug more precisely to the XEmacs people I
;;      you can reproduce it.

;;}}}
;;{{{ Old Documentation

;;  Old documentation
;;
;;      The following text was written by Jamie Lokier for the release of
;;      Folding V1.6.  It is included here for no particular reason:
;;
;;      Emacs 18:
;;      Folding mode has been tested with versions 18.55 and 18.58 of Emacs.
;;
;;      Epoch:
;;      Folding mode has been tested on Epoch 4.0p2.
;;
;;      [X]Emacs:
;;      There is code in here to handle some aspects of XEmacs.
;;      However, up to version 19.6, there appears to be no way to display
;;      folds.  Selective-display does not work, and neither do invisible
;;      extents, so Folding mode has no chance of working.  This is likely to
;;      change in future versions of XEmacs.
;;
;;      Emacs 19:
;;      Tested on version 19.8, appears to be fine.
;;      Minor bug: display the buffer in several different frames, then move
;;      in and out of folds in the buffer.  The frames are automatically
;;      moved to the top of the stacking order.
;;
;;      Some of the code is quite horrible, generally in order to avoid some
;;      Emacs display "features".  Some of it is specific to certain versions
;;      of Emacs.  By the time Emacs 19 is around and everyone is using it,
;;      hopefully most of it won't be necessary.
;;
;;  More known bugs
;;
;;      *** Needs folding-folding-region to be more intelligent about
;;      finding a good region.  Check folding a whole current fold.
;;
;;      *** Now works with 19!  But check out what happens when you exit a
;;      fold with the file displayed in two frames.  Both windows get
;;      fronted.  Better fix that sometime.
;;
;;  Future features
;;
;;      *** I will add a `folding-next-error' sometime.  It will only work with
;;      Emacs versions later than 18.58, because compile.el in earlier
;;      versions does not count line-numbers in the right way, when selective
;;      display is active.
;;
;;      *** Fold titles should be optionally allowed on the closing fold
;;      marks, and `folding-tidy-inside' should check that the opening title
;;      matches the closing title.
;;
;;      *** `folded-file' set in the local variables at the end of a file
;;      could encode the type of fold marks used in that file, and other
;;      things, like the margins inside folds.
;;
;;      *** I can see a lot of use for the newer features of Emacs 19:
;;
;;      Using invisible text-properties (I hope they are intended to
;;      make text invisible; it isn't implemented like that yet), it
;;      will be possible to hide folded text without affecting the
;;      text of the buffer.  At the moment, Folding mode uses
;;      selective display to hide text, which involves substituting
;;      carriage-returns for line-feeds in the buffer.  This isn't
;;      such a good way.  It may also be possible to display
;;      different folds in different windows in Emacs 19.
;;
;;      Using even more text-properties, it may be possible to track
;;      pointer movements in and out of folds, and have Folding mode
;;      automatically enter or exit folds as necessary to maintain a
;;      sensible display.  Because the text itself is not modified
;;      (if overlays are used to hide text), this is quite safe.  It
;;      would make it unnecessary to provide functions like
;;      `folding-forward-char', `folding-goto-line' or `folding-next-error',
;;      and things like I-search would automatically move in and out
;;      of folds as necessary.
;;
;;      Yet more text-properties/overlays might make it possible to
;;      avoid using narrowing.  This might allow some major modes to
;;      indent text properly, e.g., C++ mode.
;;

;;}}}
;;{{{ History

;; ........................................................ &t-history ...
;;; Change Log:
;; X.x                  = code under development, if number = official release
;; [person version]     = developer and his revision tree number.
;;
;; X.x   May  24  1999  19.34             [jari 2.59-2.61]
;; - New function `fold-all-comment-blocks-in-region'. Requested by
;;   Uwe Brauer <oub@eucmos.sim.ucm.es>. Bound under "/" key.
;; - (fold-all-comment-blocks-in-region):
;;   Check non-whitespace `comment-end'. Added `matlab-mode' to
;;   fold list
;;
;; X.x   Apr  15  1999  19.34             [jari 2.57]
;; - (folding-mouse-call-original):
;;   Samuel Mikes <smikes@alumni.hmc.edu> reported that the
;;   `concat' function was used to add an integer to "button" event.
;;   Applied patch to use `format' instead.
;;
;; X.x   Mar  03  1999  19.34             [andersl]
;;  - (folding-install): had extra paren. Removed.
;;
;; X.x   Feb  22  1999  19.34             [jari 2.56]
;;  - folding-install):
;;    Check if `folding-mode-prefix-map' is nil and call
;;
;; X.x   Feb  19  1999  19.34             [jari 2.55]
;;  - (folding-mode-hook-no-re):
;;    Remaned to `folding-mode-hook-no-regexp'
;;  - (fold-inside-mode-name): Renames to `folding-inside-mode-name'
;;    (fold-mode-string): Renamed to `folding-mode-string'
;;  - Renamed all `fold-' prefixes to `folding-'
;;  - Rewrote chapter `Example: personal setup'
;;
;; X.x   Jan  01  1999  19.34             [jari 2.54]
;; - Byte compiler error fix: (folding-bind-outline-compatible-keys):
;;   'folding-show-all lacked the quote.
;;
;; X.x   Dec  30  1998  19.34             [jari 2.53]
;; - Jesper Pedersen <blackie@imada.ou.dk> reorted bug that hiding subtree
;;   was broken. This turned out to be a bigger problem in fold handling in
;;   general. This release has big relatively big error fixes.
;; - Many of the folding functions were also renamed to mimic Emacs 20.3
;;   allout.el names. Outline keybindings were rewritten too.
;; - folding.el (folding-mouse-yank-at-point): Renamed from
;;   `folding-mouse-operate-at-point'. The name is similar to Emacs standard
;;   variable name. The default value changed from nil --> t according
;;   to suggestion by Jesper Pedersen <blackie@imada.ou.dk>
;;   Message "Info, Ignore [X]Emacs specific..." is now displayed only
;;   while byte compiling file.
;;   (folding-bind-outline-compatible-keys):
;;   Checked the Emacs 20.3 allout.el outline bindings and made
;;   folding mimic them
;;   (folding-show-subtree): Renamed to `folding-show-current-subtree'
;;   according to allout.el
;;   (folding-hide-subtree): Renamed to `folding-hide-current-subtree'
;;   according to allout.el
;;   (folding-enter): Renamed to `folding-shift-in'
;;   according to allout.el
;;   (folding-exit): Renamed to `folding-shift-out'
;;   according to allout.el
;;   (folding-move-up): Renamed to `folding-previous-visible-heading'
;;   according to allout.el
;;   (folding-move): Renamed to `folding-next-visible-heading'
;;   according to allout.el
;;   (folding-top-level): Renamed to `folding-show-all'
;;   according to allout.el
;;   (folding-show): Renamed to `folding-show-current-entry'
;;   according to allout.el
;;   (folding-hide): Renamed to `folding-hide-current-entry'
;;   according to allout.el
;;   (folding-region-open-close): While loop rewritten so that if user
;;   is already on a fold mark, then close current fold. This also
;;   fixed the show/hide subtree problem.
;;   (folding-hide-current-subtree): If use hide subtree that only had one
;;   fold, then calling this function caused error. The reason was error
;;   in `folding-pick-move'
;;   (folding-pick-move): Test that `moved' variable is integer and only then
;;   move point. This is the status indicator from `folding-find-folding-mark'
;;   (folding-find-folding-mark): Fixed. mistakenly moved point when checking
;;   TOP level marker, status 11. the point was permanently moved to
;;   point-min.
;;
;; X.x   Dec  29  1998  19.34             [jari 2.51]
;; - Jesper Pedersen <blackie@imada.ou.dk> reported that tjey prefix key
;;   cannot take vector notation [(key)]. This required changing the way
;;   how folding maps the keys. Now uses intermediate keymap
;;   `folding-mode-prefix-map'
;; - `folding-kbd' is new.
;; - `folding-mode' function description has better layout.
;; - `folding-get-mode-marks' is now defsubst.
;;
;; X.x   Dec  13  1998  19.34             [jari 2.49-2.50]
;; - Gleb Arshinov <gleb@CS.Stanford.EDU> reported that the XEmacs 21.0
;;   `concat' function won't accept integer argument any more and
;;   provided patch for `folding-set-mode-line'.
;;
;; X.x   Nov  28  1998  19.34             [jari 2.49-2.50]
;; - Gleb Arshinov <gleb@CS.Stanford.EDU> reported that the
;;   zmacs-region-stays must not be set blobally but in the functions that
;;   need it. He tested the change on  tested on XEmacs 21.0 beta and FSF
;;   Emacs 19.34.6 on NT and sent a patch . Thank you.
;; - (folding-preserve-active-region): New macro to set `zmacs-region-stays'
;;   to t in XEmacs.
;; - (folding-forward-char): Use `folding-preserve-active-region'
;; - (folding-backward-char): Use `folding-preserve-active-region'
;; - (folding-end-of-line):  Use `folding-preserve-active-region'
;; - (folding-isearch-general): Variables `is-fold' and `is narrowed' removed,
;;   because they were not used. (Byte Compilation fix)
;; - Later: interestingly using `defmacro' folding-preserve-active-region
;;   does not work in XEmacs 21.0 beta, bute `defsubst' does. Reported
;;   and corrected by Gleb.
;;
;; X.x   Oct  22  1998  19.34             [jari 2.47-2.48]
;; - NT Emacs has had long time a bug where it strips away ^M when closed
;;   fold is copied to kill ring. When pasted, then ^M are gone. This cover
;;   NT Emacs releases 19.34 - 20.3. Bug report has been filed.
;; - to cope with the situation I added new advice functions that get's
;;   instantiated only for these versions of NT Emacs. See `kill-new' and
;;   `current-kill'
;;
;; X.x   Oct  21  1998  19.34             [jari 2.46]
;; -  `folding-isearch-general' now enters folds as usual with isearch.
;;    The only test needed was to check `quit-isearch' before calling
;;    `folding-goto-char', because the narrow case was already taken cared of
;;    in the condition case.
;;
;; X.x   Oct  19  1998  19.34             [jari 2.44]
;; -  1998-10-19 Uwe Brauer <oub@sunma4.mat.ucm.es> reported that
;;    In Netscape version > 4 the {{{ marks cannot be used. For IE they
;;    were fine, but not for Netscape. Some bug there.
;;    --> Marks changed to [[[ ]]]
;;
;; X.x   Oct  5  1998  19.34             [jari 2.43]
;; - The "_p" flag does not exist in Emacs 19.34, so the previous patch
;;   was removed. greg@alphatech.com (Greg Klanderman) suggestd using
;;   `zmacs-region-stays'. Added to the beginning of file.
;; - todo: folding does not seem to poen folds any more with Isearch.
;;
;; X.x   Oct  5  1998  19.34             [jari 2.42]
;; - Gleb Arshinov <gleb@cs.stanford.edu> reported (and supplied patch):
;;   I am using the latest beta of folding.el with XEmacs 21.0 "Finnish
;;   Landrace" [Lucid] (i386-pc-win32) (same bug is present with folding.el
;;   included with XEmacs). Being a big fan of zmacs-region, I was
;;   disappointed to find that folding mode caused my usual way of
;;   selecting regions (e.g. to select a line C-space, C-a, C-e) to break
;;   :( I discovered that the following 3 functions would unset my mark.
;;   Upon reading some documentation, this seems to be caused by an
;;   argument to interactive used by these functions.  With the following
;;   tiny patch, the undesirable behaviour is gone.
;; - Patch was applied as is. Fucntion affected: `folding-forward-char'
;;   `folding-backward-char' `folding-end-of-line'. Interactive spec changed from
;;   "p" to "_p"
;;
;; X.x   Sep 28  1998  19.34             [jari 2.41]
;; - Wrote section "folding-whole-buffer doesn't fold whole buffer" to
;;   Problems topic. Fixed some indentation in documentation so that
;;   command  ripdoc.pl folding.el | t2html.pl --simple > folding.html
;;   works properly.
;;
;; X.x   Sep 24  1998  19.34             [jari 2.40]
;; - Stephen Smith <steve@fmrib.ox.ac.uk> wished that the `folding-comment-fold'
;;   should handle modes that have comment-start and comment-end too. That
;;   lead to rewriting the comment function so that it can be adapted to
;;   new modes.
;; - `folding-pick-move' didn't work in C-mode. Fixed.
;;    (folding-find-folding-mark):
;;    m and re must be protected with `regexp-quote'. This
;;    corrected error eg. in C-mode where `folding-pick-move'
;;    didn't move at all.
;;    (folding-comment-fold): Added support for majot modes that
;;    have `comment-start' and `comment-end'. Use
;;    `folding-comment-folding-table'
;;    (folding-comment-c-mode): New.
;;    (folding-uncomment-c-mode): New.
;;    (folding-comment-folding-table): New. To adapt to any major-mode.
;;    (folding-uncomment-mode-generic): New.
;;    (folding-comment-mode-generic): New.
;;
;; X.x   Aug 08  1998  19.34             [jari 2.39]
;; - Andrew Maccormack <andrewm@bristol.st.com> reported that the
;;   `em' end marker that was defined in the `let' should also have
;;   `[ \t\n]' which is in par with the `bm'. This way fold markers do
;;   not need to be parked to the left any more.
;;
;; X.x   Jun 05  1998  19.34             [jari 2.37-2.38]
;; - Alf-Ivar Holm <affi@osc.no> send functions `folding-toggle-enter-exit'
;;  and `folding-toggle-show-hide' which were integrated. Alf also suggested
;;  that Fold marks should now necessarily be located at the beginning
;;  of line, but allow spaces at front. The patch was applied to
;;  `folding-mark-look-at'
;;
;; X.x   Mar 17  1998  19.34             [Anders]
;; - Anders: This patch fixes one problem that was reported in the beginning
;;   of May by Ryszard Kubiak <R.Kubiak@ipipan.gda.pl>.
;; - Finally, I think that I have gotten mouse-context-sensitive right.
;;   Now, when you click on a fold that fold rather than the one the cursor
;;   is on is used, while still not breaking commands like
;;   `mouse-save-then-kill' which assumes that the point hasn't been moved.
;; - Jari: Added topic "Fold must have a label" to the Problem section.
;;   as reported by Solofo Ramangalahy <solofo@mpi-sb.mpg.de>
;;
;; - 1998-05-04 Ryszard Kubiak <R.Kubiak@ipipan.gda.pl> reported:
;;   I am just curious if it is possible to make Emacs' cursor automatically
;;   follow a mouse-click on the {{{ and }}} lines. I mean by this that a
;;   [S-mouse-3] (as defined in my settings below --- I keep not liking
;;   overloading [mouse-3]) first moves the cursor to where the click
;;   happened and then hides or shows a folded area. I presume that i can
;;   write a two-lines long interactive function to do this. Still, may be
;;   this kind of mouse behaviour is already available.
;;
;; X.x   Mar 17  1998  19.34             [Jari 2.34-2.35]
;; - Added "Example: choosing different fold marks for mode"
;; - corrected `my-folding-text-mode-setup' example.
;;
;; X.x   Mar 10  1998  19.34             [Jari 2.32-2.33]
;; - [Anders] responds to mouse-3 handling problem:
;;   I have found the cause of the problem, and I have a suggestion for a
;;   fix.
;;
;;   The problem is caused by two things:
;;    * The "mouse-save-then-kill" checks that the previous command also
;;      was "mouse-save-then-kill".
;;
;;    * The second (more severe) problem is that
;;     "folding-mouse-context-sensitive" sets the point to the location of the
;;     click, effectively making "mouse-save-then-kill" mark the area between
;;     the point and the point! (This is why no region appears.)
;;
;;   The first problem can be easily fixed by setting "this-command" in
;;   "folding-mouse-call-original":
;;
;; -  Now the good old mouse-3 binding is back again.
;; - (folding-mouse-context-sensitive): Added `save-excursion'
;;   as Anders suggested before setting `state'.
;;   (folding-mouse-call-original): commented out experimental code and
;;   used (setq this-command orig-func) as Anders suggested.
;;
;; X.x   Mar 10  1998  19.34             [Jari 2.31]
;; - (folding-act): Added `event' to `folding-behave-table' calls.
;;   Input argument takes now `event' too
;; - (folding-mouse-context-sensitive): Added argument `event'
;; - (folding-mouse-call-original): Added  (this-command orig-func)
;;   when calling original command.
;; - (folding-bind-default-mouse): Changed mouse bindings. The button-3
;;   can't be mapped by folding, because folding is unable to call
;;   the original function `mouse-save-then-kill'. Passing simple element
;;   to `mouse-save-then-kill' won't do the job. Eg if I (clicked mouse-1)
;;   moved mouse pointer to place X and pressed mouse-3, the area was not
;;   highlighted in folding mode. If folding mode was off the are was
;;   highlighted. I traced the `folding-mouse-call-original' and it was passing
;;   exactly the same event as without folding mode. I have no clue what
;;   to do about it...That's why I removed defult mouse-3 binding and left
;;   it to emacs. This bug was reported by Ryszard Kubiak" <R.Kubiak@ipipan.gda.pl>
;;
;; X.x   Feb 12  1998  19.34             [Jari 2.30]
;; - (html-mode): New mode added to `folding-mode-marks-alist'
;; - (folding-get-mode-marks): Rewritten, now return 3rd element too.
;; - (folding-comment-fold): Added note that function with `comment-end'
;;   is not supported. Function will flag error in those cases.
;; - (folding-convert-to-major-folds): Conversion failed if eg; you
;;   switched between modes that has 2 and 1 comments, like
;;   /* */ (C) and //(C++). Now the conversion is bit smarter, but it's
;;   impossible to convert from /* */ to // directly because we don't
;;   know how to remove */ mark, you see:
;;
;;   Original mode was C
;;
;;      /* {{{ */
;;
;;   And now used changed it to C++ mode, and ran command
;;   `folding-convert-to-major-folds'. We no longer have information
;;   about old mode's beginning or end comment markers, so we only
;;   can convert the folds to format
;;
;;     // {{{ */
;;
;;   Where the ending comment mark from old mode is left there.
;;   This is slightly imperfect situation, but at least the fold
;;   conversion works.
;;
;; X.x   Jan 28  1998  19.34             [Jari 2.25-2.29]
;; - Added `generic-mode' to fold list, suggested by Wayne Adams
;;   <wadams@galaxy.sps.mot.com>
;; - Finally I rewrote the awesome menu-bar code: now uses standard easy-menu
;;   Which works in both XEmacs and Emacs. The menu is no longer under
;;   "Tools", but appear when minor mode is turned on.
;; - Radical changes: Decided to remove all old lucid and epoch dependencies.
;;   Lot of code removed and reprogrammed.
;; - I also got rid of the `folding-has-minor-mode-map-alist-p' variable
;;   and old 18.xx function `folding-merge-keymaps'.
;; - Symbol's value as variable is void ((folding-xemacs-p)) error fixed.
;; - Optimized 60 `folding-use-overlays-p' calls to only 4 within
;;   `folding-subst-regions'. (Used elp.el). It seems that half of the time
;;   is spent in the function `folding-narrow-to-region' function. Could it
;;   be optimized somehow?
;; - Changed "lucid" tests to `folding-xemacs-p' variable tests.
;; - Removed `folding-hack' and print message 'Info, ignore missing functions.."
;;   instead. It's better that we see the missing functions and not
;;   define dummy hacks for them.
;;
;; X.x   Nov 13  1997  19.34             [Jari 2.18-2.24]
;; - Added tcl-mode  fold marks, suggested by  Petteri Kettunen
;;   <Petteri.Kettunen@oulu.fi>
;; - Removed some old code and modified the hook functions a bit.
;; - Added new user function `folding-convert-to-major-folds', key "%".
;; - Added missing items to Emacs menubar, didn't dare to touch the
;;   XEmacs part.
;; - `folding-comment-fold': Small fix. commenting didn't work on closed folds.
;;   or if point was on topmost fold.
;; - Added `folding-advice-instantiate' And corrected byte compiler message:
;;   Warning: variable oldposn bound but not referenced
;;   Warning: reference to free variable folding-stack
;; - updated (require 'custom) code
;;
;; X.x   Nov 6  1997  19.34             [Jari 2.17]
;; - Uwe Brauer <oub@sunma4.mat.ucm.es> used folding for Latex files and
;;   he wished a feature that would allow him to comment away ext that
;;   was inside fold; when compiling the TeX file.
;; - Added new user function `folding-comment-fold'. And new keybinding ";".
;;
;; X.x   Oct 8  1997  19.34             [Jari 2.16]
;; - Now the minor mode map is always re-installed when this file is loaded.
;;   If user accidentally made mistake in `folding-default-keys-function',
;;   he can simply try again and reload this file to have the new
;;   keydefinitions.
;; - Previously user had to manually go and dfelete the previous map from
;;   the `minor-mode-map-alist' before he could try again.
;;
;; X.x   Sep 29 1997  19.34             [Jari 2.14-2.15]
;; - Robert Marshall <rxmarsha@bechtel.com> Sent enchancement to goto-line
;;   code. Now M-g works more intuitively.
;; - Reformatted totally the documentation so that it can be ripped to
;;   html with jari's ema-doc.pls and t2html.pls Perl scripts.
;; - Run through checkdoc.el 1.55 and Elint 1.10 and corrected code.
;; - Added defcustom support. (not tested)
;;
;; X.x   Sep 19 1997  19.28             [Jari 2.13]
;; - Robert Marshall <rxmarsha@bechtel.com> Sent small correction to
;;   overlay code, where the 'owner tag was set wrong.
;;
;; X.x   Aug 14 1997  19.28             [Jari 2.12 ]
;; - A small regexp bug (extra whitespace was required after closing fold)
;;   cause failing of folding-convert-buffer-for-printing in the following situation
;; - Reported by Guido. Fixed now.
;;
;;   {{{ Main topic
;;   {{{ Subsection
;;   }}}               << no space or end tag here!
;;   }}} Main topic
;;
;; X.x   Aug 14 1997  19.28             [Jari 2.11]
;; - Guido Van Hoecke <Guido.Van.Hoecke@bigfoot.com> reported that
;;   he was using closing text for fold like:
;;
;;   {{{ Main topic
;;   {{{ Subsection
;;   }}} Subsection
;;   }}} Main topic
;;
;;   And when he did folding-convert-buffer-for-printing, it couldn't remove those closing
;;   marks but thorewed an error. I modified the function so that the
;;   regexp accepts anything after closing fold.
;;
;; X.x   Apr 18 1997  19.28             [Jari 2.10]
;; - Corrected function folding-show-current-subtree, which didn't find the
;;   correct end region, because folding-pick-move needed point at the
;;   top of beginning fold. Bug was reported by Uwe Brauer
;;   <oub@sunma4.mat.ucm.es> Also changed folding-mark-look-at, which now
;;   has new call parameter 'move.
;;
;; X.x   Mar 22 1997  19.28             [Jari 2.9]
;; - Made the XEmacs20 match more stricter, so that folding-emacs-version
;;   gets value 'XEmacs19. Also added note about folding in WinNT in the
;;   compatibility section.
;; - Added sh-script-mode indented-text-mode folding marks.
;; - Moved the version from brach to the root, because the extra
;;   overlay code added, seems to be behaving well and it dind't break
;;   the existing functionality.
;;
;; X.x   Feb 17 1997  19.28             [Jari 2.8.1.2]
;; - Cleaned up Dan's changes. First: we must not replace the selective
;;   display code, but offer these two choices: Added folding-use-overlays-p
;;   function which looks variable folding-allow-overlays.
;; - Dan uses function from another Emacs specific (19.34+?) package
;;   hs-discard-overlays. This is not available in 19.28. it should
;;   be replaced with some new function... I didn't do that yet.
;; - The overlays don't exist in XEmacs. XE19.15 has promises: at least
;;   I have heard that they have overlay.el library tomimic Emacs
;;   functions.
;; - Now the overlay support can be turned on by setting
;;   folding-allow-overlays to non-nil. The default is to use selective
;;   display. Overlay Code is not tested!
;;
;; X.x   Feb 17 1997  19.28             [Dan  2.8.1.1]
;; - Dan Nicolaescu <done@ece.arizona.edu> sent patch that replaced
;;   selective display code with overlays.
;;
;; X.x   Feb 10 1997  19.28             [jari 2.8]
;; - Ricardo Marek <ricky@ornet.co.il> Kindly sent patch that
;;   makes code XEmacs 20.0 compatible. Thank you.
;;
;; X.x   Nov 7  1996  19.28             [jari 2.7]
;; - When I was on picture-mode and turned on folding, and started
;;   isearch (I don't remember how I got fold mode on exactly) it
;;   gave error that the fold marks were not defined and emacs
;;   locked up due to simultaneous isearch-loop
;; - Added few fixes to the isearch handling function to avoid
;;   infinite error loops.
;;
;; X.x   Nov 6 1996  19.28              [jari 2.5 - 2.6]
;; - Situation: have folded buffer, manually _narrow_ somewhere, C-x n n
;; - Then try searching --> folding breaks. Now it checks if the
;;   region is true narrow and not folding-narrow before trying
;;   to go outside of region and open a fold
;; - If it's true narrow, then we stay in that narrowed region.
;;
;;   folding-isearch-general               :+
;;   folding-region-has-folding-marks-p       :+
;;
;; X.x   Oct 23 1996  19.28             [jari 2.4]
;;   folding-display-name                  :+ new user cmd "C-n"
;;   folding-find-folding-mark                :+
;;   folding-pick-move                     :! rewritten, full of bugs
;;   folding-region-open-close             :! rewritted, full of bugs
;;
;; X.x   Oct 22 1996  19.28             [jari 2.3]
;; - folding-pick-move                     :! rewritten
;;   folding-region-open-close             :+ new user cmd "#"
;;   folding-show-current-subtree          :+ new user cmd "C-s", hides too
;;
;; X.x   Aug 01 1996  19.31             [andersl]
;; - folding-subst-regions, variable `font-lock-mode' set to nil.
;;   (Thanks to "stig@hackvan.com")
;;
;; X.x   Jun 19 1996  19.31             [andersl]
;; - The code has proven iteself stable through the beta testing phase
;;   which has lasted the past six monts.
;; - A lot of comments written.
;; - The package `folding-isearch' integrated.
;; - Some code cleanup:
;;   BOLP -> folding-BOL                   :! renamed
;;   folding-behave-table                  :! field `down' removed.
;;
;;
;; X.x   Mar 14 1996  19.28             [jari  1.27]
;; - No code changes. Only some textual corrections/additions.
;; - Section "about keymaps" added.
;;
;; X.x   Mar 14 1996  19.28             [jackr 1.26]
;; - spell-check run over code.
;;
;; X.x   Mar 14 1996  19.28             [davidm 1.25]
;; - David Masterson <davidm@prism.kla.com> This patch makes the menubar in
;;   XEmacs work better.  After I made this patch, the Hyperbole menus
;;   starting working as expected again.  I believe the use of
;;   set-buffer-menubar has a problem, so the recommendation in XEmacs
;;   19.13 is to use set-menubar-dirty-flag.
;;
;; X.x   Mar 13 1996  19.28             [andersl 1.24]
;; - Corrected one minor bug in folding-check-if-folding-allowed
;;
;; X.x   Mar 12 1996  19.28             [jari 1.23]
;; - Renamed all -func variables to -function.
;;
;; X.x   mar 12 1996  19.28             [jari 1.22]
;; - Added new example how to change the fold marks. The automatic folding
;;   was reported to cause unnecessary delays for big files (eg. when using
;;   ediff) Now there is new function variable which can totally disable
;;   automatic folding if the return value is nil.
;;
;;   folding-check-allow-folding-function       :+ new variable
;;   folding-check-if-folding-allowed   :+ new func
;;   folding-mode-find-file             :! modified
;;   folding-mode-write-file            :! better docs
;;   folding-goto-line                     :! arg "n" --> "N" due to XEmacs 19.13
;;
;; X.x   Mar 11 1996  19.28             [jari 1.21]
;; - Integrated changes made by Anders's to v1.19 [folding in beta dir]
;;
;; X.x   Jan 25 1996  19.28             [jari 1.20]
;; - ** Mainly cosmetical changes **
;; - Added some 'Section' codes that can be used with lisp-mnt.el
;; - Deleted all code in 'special section' because it was never used.
;; - Moved some old "-v-" named variables to better names.
;; - Removed folding-mode-flag that was never used.
;;
;; X.x   Jan 25 1996  19.28             [jari 1.19]
;; - Put Ander's lates version into RCS tree.
;;
;; X.x   Jan 03 1996  19.30             [andersl]
;; - `folding-mouse-call-original' uses `call-interactively'.
;;   `folding-mouse-context-sensitive' doesn't do `save-excursion'.
;;   (More changes will come later.)
;;   `folding-mouse-yank-at-p' macro corrected  (quote added).
;;   Error for `epoch::version' removed.
;;   `folding-mark-look-at' Regexp change .* -> [^\n\r]* to avoid error.
;;
;; X.x   Nov 24 1995  19.28             [andersl]
;; - (sequencep ) added to the code which checks for the existence
;;   of a tools menu.
;;
;; X.x   Aug 27 1995  19.28 19.12       [andersl]
;; - Keybindings restructurated.  They now conforms with the
;;   new 19.29 styleguide.  Old keybinds are still available.
;; - Menues new goes into the "Tools" menu, if present.
;; - `folding-mouse-open-close' renamed to `folding-mouse-context-sensitive'.
;; - New entry `other' in `folding-behave-table' which defaults to
;;   `folding-calling-original'.
;; - `folding-calling-original' now gets the event from `last-input-event'
;;   if called without arguments (i.e. the way `folding-act' calls it.)
;; - XEmacs mouse support added.
;; - `folding-mouse-call-original' can call functions with or without
;;   the Event argument.
;; - Byte compiler generates no errors neither for Emacs 19 and XEmacs.
;;
;; X.x   Aug 24 1995  19.28             [jari  1.17]
;; - To prevent infinite back calling loop, Anders suggested smart way
;;   to detect that func call chain is started only once.
;;   folding-calling-original      :+ v, call chain terminator
;;   "Internal"                 :! v, all private vars have this string
;;   folding-mouse-call-original   :! v, stricter chain check.
;;   "copyright"                :! t, newer notice
;;   "commentary"               :! t, ripped non-supported emacses
;;
;; X.x   Aug 24 1995  19.28             [jari  1.16]
;; ** mouse interface rewritten
;; - Anders gave many valuable comments about simplifying the mouse usage,
;;   he suggested that every mouse function should accept standard event,
;;   and it should be called directly.
;;   folding-global                 :- v, not needed
;;   folding-mode-off-hook       :- v, no usage
;;   folding-mouse-action-table     :- v, not needed any more
;;   folding-default-keys-function  :+ v, key settings
;;   folding-default-mouse-keys-function:+ v, key settings
;;   folding-mouse                  :- f, unnecessary
;;   'all mouse funcs'           :! f, now accept "e" parameter
;;   folding-default-keys           :+ f, defines keys
;;   folding-mouse-call-original    :+ f, call orig mouse func
;;   "examples"                  :! t, radical rewrote, only one left
;;
;; X.x   Aug 24 1995  19.28             [jari  1.15]
;; - some minor changes. If we're inside a fold, Mouse-3 will go one
;;   level up if it points END or BEG marker.
;;   folding-mouse-yank-at-point:! v, added 'up 'down
;;   folding-mark-look-at          :! f, more return values: '11 and 'end-in
;;   folding-open-close            :! f, bug, didn't exit if inside fold
;;   PMIN, PMAX, NEXTP, add-l   :+ more macros fom tinylibm.el
;;
;; X.x   Aug 23 1995  19.28             [andersl 1.14]
;; - Added `eval-when-compile' around 1.13 byte-compiler fix
;;   to avoid code to be executed when using a byte-compiled version
;;   of folding.el.
;; - Binds mode keys via `minor-mode-map-alist' (i.e. `folding-merge-keymaps'
;;   is not used in modern Emacses.)  This means that the user can not
;;   bind `folding-mode-map' to a new keymap, \\(s\\|\\)he must modify
;;   the existing one.
;; - `defvars' for global feature test variables `folding-*-p'.
;; - `folding-mouse-open-close' now detectes when the current fold was been
;;   pressed.  (The "current" is the fold around which the buffer is
;;   narrowed.)
;;
;; X.x   Aug 23 1995  19.28             [jari  1.13]
;; - 19.28 Byte compile doesn't handle fboundp, boundp well. That's a bug.
;;   Set some dummy functions to get cleaner output.
;; - The folding-mode-off doesn't seem very usefull, because it
;;   is never run when another major-mode is turned on ... maybe we should
;;   utilize kill-all-local-variables-hooks with defadvice around
;;   kill-all-local-variables ...
;;
;;   folding-emacs-version         :+ added. it was in the docs, but not defined
;;   kill-all-local-variables-hooks  :! v, moved to variable section
;;   list-buffers-mode-alist         :! v, --''--
;;   "compiler hacks"                :+ section added
;;   "special"                       :+ section added
;;   "Compatibility"                 :! moved at the beginning
;;
;; X.x   Aug 22 1995  19.28             [jari  1.12]
;; - Only minor changes
;;   BOLP, BOLPP, EOLP, EOLPP   :+ f, macros added from tinylibm.el
;;   folding-mouse-pick-move       :! f, when cursor at beolp, move always up
;;   "bindings"                 :+ added C-cv and C-cC-v
;;
;; X.x   Aug 22 1995  19.28             [jari  1.11]
;; - Inpired by mouse so much, that this revision contain substantial
;;   changes and enchancements. Mouse is now powered!
;; - Anders wanted mouse to operate according to 'mouse cursor', not
;;   current 'point'.
;;   folding-mouse-yank-at-point: controls it. Phwew, I like this one a lot!
;;   examples                   :! t, totally changed, now 2 choices
;;   folding-mode-off-hook      :+ v, when folding ends
;;   folding-global                :+ v, global store value
;;   folding-mouse-action-table    :! v, changed
;;   folding-mouse                 :! f, stores event to global
;;   folding-mouse-open-close      :! f, renamed, mouse activated open
;;   folding-mode               :! f, added 'off' hook
;;   folding-event-posn            :+ f, handles FSF mouse event
;;   folding-mouse-yank-at-p       :+ f, check which mouse mode is on
;;   folding-mouse-point           :+ f, return working point
;;   folding-mouse-move            :+ f, mouse moving down  , obsolete ??
;;   folding-mouse-pick-move       :+ f, mouse move accord. fold mark
;;   folding-next-visible-heading  :+ f, from tinyfold.el
;;   folding-previous-visible-heading :+ f, from tinyfold.el
;;   folding-pick-move             :+ f, from tinyfold.el
;;
;;
;; X.x   Aug 22 1995  19.28             [jari  1.10]
;; - Minor typing errors corrected : fol-open-close 'hide --> 'close
;;   This caused error when trying to close open fold with mouse
;;   when cursor was sitting on fold marker.
;;
;; X.x   Aug 22 1995  19.28             [jari  1.9]
;; - Having heard good suggestions from Anders...!
;;   "install"                  : add-hook for folding missed
;;   folding-open-close            : generalized
;;   folding-behave-table          : NEW, logical behavior control
;;   folding-:mouse-action-table   : now folding-mouse-action-table
;;
;; - The mouse function seems to work with FSF emacs only, because
;;   XEmacs doesn't know about double or triple clicks. We're working
;;   on the problem...
;;
;; X.x   Aug 21 1995  19.28             [jari  1.8]
;; - Rearranged the file structure so that all variables are at the
;;   beginning of file. With new functions, it easy to open-close
;;   fold.  Added word "code:" or "setup:" to the front of code folds,
;;   so that the toplevel folds can be recognized more easily.
;; - Added example hook to install section for easy mouse use.
;; - Added new functions.
;;   folding-get-mode-marks        : returns folding marks
;;   folding-mark-look-at          : status of current line, fold mark in it?
;;   folding-mark-mouse            : exec action on fold mark
;;
;;
;; X.x   Aug 17 1995  19.28/X19.12      [andersl 1.7]
;; - Failed when loaded into XEmacs, when `folding-mode-map' was undefined.
;;   Folding marks for three new major modes added: rexx-mode, erlang-mode
;;   and xerl-mode.
;;
;; X.x   Aug 14 1995  19.28             [jari  1.6]
;; - After I met Anders we exchanged some thoughts about usage philopsophy
;;   of error and signal commands. I was annoyed by the fact that they
;;   couldn't be suppressed, when the error was "minor". Later Anders
;;   developed fdb.el, which will be intergrated to FSF 19.30. It
;;   offers by-passing error/signal interference.
;;   --> I changed back all the error commands that were taken away.
;;
;; X.x   Jun 02 1995  19.28             [andersl]
;; - "Narrow" not present in mode-line when in folding-mode.
;;
;; X.x   May 12 1995  19.28             [jari  1.5]
;; - Installation text cleaned: reference to 'install-it' removed,
;;   because such function doesn't exist any more. The istallation is
;;   now automatic: it's done when user calls folding mode first time.
;; - Added 'private vars' section. made 'outside all folds' message
;;   informational, not an error.
;;
;; X.x   May 12 1995  19.28             [jackr  x.x]
;; - Corrected 'broken menu bar' problem.
;; - Even though make-sparse-keymap claims its argument (a string to
;;   name the  menu) is optional, it's not. Lucid has other
;;   arrangements for the same thing..
;;
;; X.x   May 10 1995  19.28             [jari 1.2]
;; - Moved provide to the end of file.
;; - Rearranged code so that the common functions are at the beginning.
;;   Reprogrammed the whole installation with hooks. Added Write file
;;   hook that makes sure you don't write in 'binary' while folding were
;;   accidentally off.
;; - Added regexp text for certain files which are not allowed to 'auto fold'
;;   when loaded.
;; - changed some 'error' commands to 'messages', this prevent screen
;;   mixup when debug-on-error is set to t
;; + folding-list-delete , folding-msg , folding-mode-find-file ,
;;   folding-mode-write-file , folding-check-folded , folding-keep-hooked
;;
;; 1.7.4 May 04 1995  19.28             [jackr 1.11]
;; - Some compatibility changes:
;;      v.18 doesn't allow an arg to make-sparse-keymap
;;      testing epoch::version is trickier than that
;;      free-variable reference cleanup
;;
;; 1.7.3 May 04 1995  19.28             [jari]
;; - Corrected folding-mode-find-file-hook , so that it has more
;;   'mode turn on' cababilitis through user function
;; + folding-mode-write-file-hook: Makes sure your file is saved
;;   properly, so that you don't end up saving in 'binary'.
;; + folding-check-folded: func, default checker provided
;; + folding-check-folded-file-function variable added, User can put his
;;   'detect folding.el file' methods here.
;; + folding-mode-install-it: func, Automatic installation with it
;;
;; 1.7.2  Apr 01 1995   19.28           [jackr] , Design support by [jari]
;; - Added folding to FSF & XEmacs menus
;;
;; 1.7.1  Apr 28 1995   19.28           [jackr]
;; - The folding editor's merge-keymap couldn't handle FSF menu-bar,
;;   so some minor changes were made, previous is '>' and enhancements
;;   are '>'
;;
;; <     (buffer-disable-undo new-buffer)
;; ---
;; >     (buffer-flush-undo new-buffer)
;; 1510,1512c1510
;; <                    key (if (symbolp keycode)
;; <                            (vector keycode)
;; <                          (char-to-string keycode))
;; ---
;; >                    key (char-to-string keycode)
;; 1802,1808d1799
;; < ;;{{{ Compatibility hacks for various Emacs versions
;; <
;; < (or (fboundp 'buffer-disable-undo)
;; <     (fset 'buffer-disable-undo (symbol-function 'buffer-flush-undo)))
;; <
;; < ;;}}}
;;
;;
;; X.x  Dec 1   1994    19.28           [jari]
;; - Only minor change. Made the folding mode string user configurable.
;;   Added these variables:
;;   o     folding-mode-string , folding-inside-string,folding-inside-mode-name
;; - Changed revision number from 1.6.2 to 1.7 , so that people know
;;   this el has changed.
;; - Advertise: I made couple of extra functions for this module, please
;;   look at the goodies in tinyfold.el.

;;}}}

;;{{{ LCD Entry:

;; LCD Archive Entry:
;; folding|Jamie Lokier|jamie@rebellion.co.uk|
;; A folding-editor-like minor mode|
;; 25-Jun-1996|?.?|~/modes/folding.el.Z|

;;}}}

;;; Code:

;;{{{ setup: require packages

;;; ......................................................... &require ...

(eval-when-compile (require 'cl))
(require 'easymenu)


;;}}}
;;{{{ setup: byte compiler hacks

;;; ............................................. &byte-compiler-hacks ...
;;; - This really only should be evaluted in case we're about to byte
;;;   compile this file.  Since `eval-when-compile' is evaluated when
;;;   the uncompiled version is used (great!) we test if the
;;;   byte-compiler is loaded.


;; Make sure `advice' is loaded when compiling the code.

(eval-and-compile

  (require 'advice)

  (defvar folding-xemacs-p (boundp 'xemacs-logo)
    "Folding determines which emacs version it is running. t if Xemacs.")

  ;;  loading overlay.el package removes some byte compiler whinings.
  ;;  By default folding does not use overlay code.
  ;;
  (if folding-xemacs-p
      (or (fboundp 'overlay-start)  ;; Already loaded
	  (load "overlay" 'noerr)   ;; Try to load it then.
	  (message "\
** folding.el: XEmacs 19.15+ has package overlay.el, try to get it.
               Folding does not use overlays by default.
               You can safely ignore possible overlay byte compilation
               messages."))))


(eval-when-compile

  (if (string= (buffer-name) " *Compiler Input*")  ;; While byte compiling
      (progn
	(message "** folding.el:\
 Info, Ignore [X]Emacs specific missing event-/posn- functions calls")))


  (defadvice make-sparse-keymap
    (before
     make-sparse-keymap-with-optional-argument
     (&optional byte-compiler-happyfier)
     activate)
    "This advice does nothing except adding an optional argument
to keep the byte compiler happy when compiling Emacs specific code
with XEmacs.")

  ;; XEmacs and Emacs 19 differs when it comes to obsolete functions.
  ;; We're using the Emacs 19 versions, and this simply makes the
  ;; byte-compiler stop wining. (Why isn't there a warning flag which
  ;; could have turned off?)

  (and (boundp 'mode-line-format)
       (put 'mode-line-format 'byte-obsolete-variable nil))

  (and (fboundp 'byte-code-function-p)
       (put 'byte-code-function-p 'byte-compile nil))

  (and (fboundp 'eval-current-buffer)
       (put 'eval-current-buffer 'byte-compile nil))

  )


(defsubst folding-preserve-active-region ()
  "In XEmacs keep the region alive. In Emacs do nothing."
  (if (boundp 'zmacs-region-stays)	;Keep regions alive
      (set 'zmacs-region-stays t)))	;use `set' to Quiet Emacs Byte Compiler



;; Work around the NT Emacs Cut'n paste bug in selective-display which
;; doens't preserve C-m's.

(when (and (not folding-xemacs-p)
	   (memq (symbol-value 'window-system) '(win32 w32)) ; NT Emacs
	   (string< emacs-version "20.4")) ;at least in 19.34 .. 20.3.1

  (unless (fboundp 'char-equal)
    (defalias 'char-equal  'equal))

  (unless (fboundp 'subst-char)
    (defun subst-char (str char to-char)
      "Replace in STR every CHAR with TO-CHAR."
      (let ((len   (length str))
	    (ret   (copy-sequence str))     ;because 'aset' is destructive
	    )
	(while (> len 0)
	  (if (char-equal (aref str (1- len)) char)
	      (aset ret (1- len) to-char))
	  (decf len))
	ret)))

  (defadvice kill-new (around folding-win32-fix-selective-display act)
    "In selctive display, convert each C-m to C-a. See `current-kill'."
    (let* ((string (ad-get-arg 0)))
      (when (and selective-display (string-match "\C-m" (or string "")))
	(setq string (subst-char string ?\C-m ?\C-a)))
      ad-do-it))


  (defadvice current-kill (around folding-win32-fix-selective-display  act)
    "In selctive display, convert each C-a back to C-m. See `kill-new'."
    ad-do-it
    (let* ((string ad-return-value))
      (when (and selective-display (string-match "\C-a" (or string "")))
	(setq string (subst-char string ?\C-a ?\C-m))
	(setq ad-return-value string))))
  )

;;}}}

;;{{{ setup: some variable

;;; .................................................. &some-variables ...


;; This is a list of structures which keep track of folds being entered
;; and exited. It is a list of (MARKER . MARKER) pairs, followed by the
;; symbol `folded'.  The first of these represents the fold containing
;; the current one.  If the view is currently outside all folds, this
;; variable has value nil.

(defvar folding-stack nil
  "Internal. A list of marker pairs representing folds entered so far.")


(defvar folding-version  (substring "$Revision$" 11 15)
  "Version number of folding.el")

;;}}}
;;{{{ setup: bind

;;; .......................................................... &v-bind ...

;; Custom hack for Emacs that does not have custom
;;

;; http://www.dina.kvl.dk/~abraham/custom/
(eval-and-compile
  (condition-case ()
      (require 'custom)
    (error nil))
  (if (and (featurep 'custom) (fboundp 'custom-declare-variable))
      nil ;; We've got what we needed
    ;; We have the old custom-library, hack around it!
    (defmacro defgroup (&rest args)
      nil)
    (defmacro defcustom (var value doc &rest args)
      (` (defvar (, var) (, value) (, doc))))))


(defgroup folding nil
  "Managing buffers with Folds."
  :group 'tools)

(defcustom folding-mode-prefix-key "\C-c@"
  "*Prefix key to use for Folding commands in Folding mode."
  :type 'string  :group 'folding)

(defcustom folding-goto-key "\M-g"
  "*Key to be bound to `folding-goto-line' in folding mode.
The default value is M - g, but you propably don't want folding to
occupy it if you have used M - g got `goto-line'."
  :type 'string  :group 'folding)


(defvar folding-mode-map nil
  "Keymap used in Folding mode (a minor mode).")

(defvar folding-mode-prefix-map nil
  "Keymap used in Folding mode keys sans `folding-mode-prefix-key'.")

(defvar folding-mode nil
  "When Non nil, Folding mode is active in the current buffer.")



(defmacro folding-kbd (key function)
  "folding: define key macro.
This is used when assigning keybindings to `folding-mode-map'.
See also `folding-mode-prefix-key'."
  (` (define-key
       folding-mode-prefix-map
       (, key) (, function))))


(defun folding-bind-default-mouse ()
  "Bind default mouse keys used by Folding mode."
  (interactive)
  (cond
   (folding-xemacs-p
    (define-key folding-mode-map '(shift button2)
      'folding-mouse-context-sensitive)
    ;; (define-key folding-mode-map '(double button3) 'folding-hide-current-entry)
    (define-key folding-mode-map '(control shift button2)
      'folding-mouse-pick-move)
    )

   (t
    (define-key folding-mode-map [mouse-3]       'folding-mouse-context-sensitive)
    (define-key folding-mode-map [double-mouse-3] 'folding-hide-current-entry)
    (define-key folding-mode-map [C-S-mouse-2]    'folding-mouse-pick-move)
    )))


(defun folding-bind-default-keys ()
  "Bind the default keys used the `folding-mode'.

The variable `folding-mode-prefix-key' contains the prefix keys,
the default is C - c @.

For the good ol' key bindings, please use the function
`folding-bind-backward-compatible-keys' instead."
  (interactive)

  (define-key folding-mode-map folding-goto-key 'folding-goto-line)
  (define-key folding-mode-map "\C-f" 'folding-forward-char)
  (define-key folding-mode-map "\C-b" 'folding-backward-char)
  (define-key folding-mode-map "\C-e" 'folding-end-of-line)

  (folding-kbd ">"	'folding-shift-in)
  (folding-kbd "<"	'folding-shift-out)
  (folding-kbd "\C-t"	'folding-show-all)
  (folding-kbd "\C-f"	'folding-folding-region)
  (folding-kbd "\C-s"	'folding-show-current-entry)
  (folding-kbd "\C-x"	'folding-hide-current-entry)
  (folding-kbd "\C-o"	'folding-open-buffer)
  (folding-kbd "\C-w"	'folding-whole-buffer)

  (folding-kbd "\C-r"	'folding-convert-buffer-for-printing)


  (folding-kbd	"\C-v"	'folding-pick-move)
  (folding-kbd	"v"	'folding-previous-visible-heading)
  (folding-kbd	" "	'folding-next-visible-heading)

  ;;  C-u:  kinda "up" -- "down"

  (folding-kbd "\C-u"	'folding-toggle-enter-exit)
  (folding-kbd "\C-q"	'folding-toggle-show-hide)

  ;; Think "#" as a 'fence'

  (folding-kbd "#"	'folding-region-open-close)

  ;; Esc-; is the standard emacs commend add key.

  (folding-kbd ";"	'folding-comment-fold)
  (folding-kbd "%"	'folding-convert-to-major-folds)
  (folding-kbd "/"	'fold-all-comment-blocks-in-region)

  (folding-kbd "\C-y"	'folding-show-current-subtree)
  (folding-kbd "\C-z"	'folding-hide-current-subtree)
  (folding-kbd "\C-n"	'folding-display-name)
  )



(defun folding-bind-backward-compatible-keys ()
  "Bind keys traditionally used by Folding mode.
For bindings which follows Emacs 19.29 style conventions, please
use the function `folding-bind-default-keys'.

This function ignores the variable `folding-mode-prefix-key'!"
  (interactive)
  (let ((folding-mode-prefix-key "\C-c"))
    (folding-bind-default-keys)))



(defun folding-bind-outline-compatible-keys ()
  "Bind keys used by the minor mode `folding-mode'.
The keys used are as much as possible compatible with
bindings used by Outline mode.

Currently, some outline mode functions doesn't have a corresponding
folding function.

The variable `folding-mode-prefix-key' contains the prefix keys,
the default is C - c @.

For the good ol' key bindings, please use the function
`folding-bind-backward-compatible-keys' instead."
  (interactive)

  ;; Traditional keys:

  (define-key folding-mode-map "\C-f" 'folding-forward-char)
  (define-key folding-mode-map "\C-b" 'folding-backward-char)
  (define-key folding-mode-map "\C-e" 'folding-end-of-line)

  ;; Mimic Emacs 20.3 allout.el bindings

  (folding-kbd ">"	    'folding-shift-in)
  (folding-kbd "<"	    'folding-shift-out)
  (folding-kbd "\C-n"  'folding-next-visible-heading)
  (folding-kbd "\C-p"  'folding-previous-visible-heading)

  ;; ("\C-u" outline-up-current-level)
  ;; ("\C-f" outline-forward-current-level)
  ;; ("\C-b" outline-backward-current-level)
  ;;  (folding-kbd "\C-i"  'folding-show-current-subtree)

  (folding-kbd "\C-s" 'folding-show-current-subtree)
  (folding-kbd "\C-h" 'folding-hide-current-subtree)

  (folding-kbd "!"     'folding-show-all)

  (folding-kbd "\C-d"  'folding-hide-current-entry)
  (folding-kbd "\C-o"  'folding-show-current-entry)

  ;; (" " outline-open-sibtopic)
  ;; ("." outline-open-subtopic)
  ;; ("," outline-open-supertopic)

  ;; Other bindings not in allout.el

  (folding-kbd "\C-a"  'folding-open-buffer)
  (folding-kbd "\C-q"  'folding-whole-buffer)

  (folding-kbd "\C-r"  'folding-convert-buffer-for-printing)
  (folding-kbd "\C-w"  'folding-folding-region)

  )


;;{{{ goto-line (advice)


(defcustom folding-advice-instantiate t
  "*In non-nil install advice code. Eg for `goto-line'."
  :type 'boolean  :group  'folding
  )

(defcustom folding-shift-in-on-goto t
  "*Flag in folding adviced fucntion `goto-line'
If non-nil, folds are entered when going to a given line.
Otherwise the buffer is unfolded. Can also be set to 'show.
This variable is used only if `folding-advice-instantiate' was
non-nil when folding was loaded.

See also `folding-goto-key'."
  :type 'boolean  :group 'folding)

(when folding-advice-instantiate
  (eval-when-compile (require 'advice))
  ;; By Robert Marshall <rxmarsha@bechtel.com>
  ;;
  (defadvice goto-line (around folding-goto-line first activate)
    "Go to line ARG, entering folds if `folding-shift-in-on-goto' is t.
It attempts to keep the buffer in the same visibility state as before."
    (let (
	  ;; (oldposn (point))
	  )
      ad-do-it
      (if (and folding-mode
	       (or (folding-point-folded-p (point))
		   (<= (point) (point-min-marker))
		   (>= (point) (point-max-marker)))
	       )
	  (let ((line (ad-get-arg 0)))
	    (if folding-shift-in-on-goto
		(progn
		  (folding-show-all)
		  (goto-char 1)
		  (and (< 1 line)
		       (not (folding-use-overlays-p))
		       (re-search-forward "[\n\C-m]" nil 0 (1- line)))
		  (let ((goal (point)))
		    (while (prog2 (beginning-of-line)
			       (if (eq folding-shift-in-on-goto 'show)
				   (progn
				     (folding-show-current-entry t t)
				     (folding-point-folded-p goal))
				 (folding-shift-in t))
                             (goto-char goal)))
		    (folding-narrow-to-region (point-min) (point-max) t)))
	      (if (or folding-stack (folding-point-folded-p (point)))
		  (folding-open-buffer))))))))


;;}}}


(defun folding-bind-foldout-compatible-keys ()
  "Bind keys for `folding-mode' compatible with Foldout mode.

The variable `folding-mode-prefix-key' contains the prefix keys,
the default is C - c @."
  (interactive)
  (folding-kbd "\C-z" 'folding-shift-in)
  (folding-kbd "\C-x" 'folding-shift-out))


;;; I write this function, just in case we ever would like to add
;;; `hideif' support to folding mode.  Currently, it is only used to
;;; remind me which keys I shouldn't use.

;;(defun folding-bind-hideif-compatible-keys ()
;;  "Bind keys for `folding-mode' compatible with Hideif mode.
;;
;;The variable `folding-mode-prefix-key' contains the prefix keys,
;;the default is C-c@."
;;  (interactive)
;;    ;; Keys defined by `hideif'
;;    ;; (folding-kbd "d" 'hide-ifdef-define)
;;    ;; (folding-kbd "u" 'hide-ifdef-undef)
;;    ;; (folding-kbd "D" 'hide-ifdef-set-define-alist)
;;    ;; (folding-kbd "U" 'hide-ifdef-use-define-alist)
;;
;;    ;; (folding-kbd "h") 'hide-ifdefs)
;;    ;; (folding-kbd "s") 'show-ifdefs)
;;    ;; (folding-kbd "\C-d") 'hide-ifdef-block)
;;    ;; (folding-kbd "\C-s") 'show-ifdef-block)
;;
;;    ;; (folding-kbd "\C-q" 'hide-ifdef-toggle-read-only)
;;    )


;;; .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .


;; Not used for modern Emaxen.
(defvar folding-saved-local-keymap nil
  "Keymap used to save non-folding keymap.
(so it can be restored when folding mode is turned off.)")

(defcustom folding-default-keys-function 'folding-bind-default-keys
  "*Function or list of functions used to define keys for Folding mode.
Possible values are:
  folding-bind-default-key
        The standard keymap.

  `folding-bind-backward-compatible-keys'
        Keys used by older versions of Folding mode.  This function
        does not conform to Emacs 19.29 style conversions concerning
        key bindings.  The prefix key is C - c

  `folding-bind-outline-compatible-keys'
        Define keys compatible with Outline mode.

  `folding-bind-foldout-compatible-keys'
        Define some extra keys compatible with Foldout.

All except `folding-bind-backward-compatible-keys' used the value of
the variable `folding-mode-prefix-key' as prefix the key.
The default is C - c @"
  :type 'function  :group 'folding)


;; Not yet implemented:
;;  folding-bind-hideif-compatible-keys
;;      Define some extra keys compatible with hideif.


(defcustom folding-default-mouse-keys-function 'folding-bind-default-mouse
  "*Function to bind default mouse keys to `folding-mode-map'."
  :type 'function  :group 'folding)



(defvar folding-mode-menu nil
  "Keymap containing the menu for Folding mode.")

(defvar folding-mode-menu-name "Fld"	;; Short menu name
  "Name of pull down menu.")

;;}}}
;;{{{ setup: hooks

;;; ......................................................... &v-hooks ...

(defcustom folding-mode-hook nil
  "*Hook called when Folding mode is entered.

A hook named `<major-mode>-folding-hook' is also called, if it
exists.  Eg., `c-mode-folding-hook' is called whenever Folding mode is
started in C mode."
  :type 'hook  :group 'folding)

(defcustom folding-load-hook nil
  "*Hook run when file is loaded."
  :type 'hook  :group 'folding)

;;}}}
;;{{{ setup: private

;;; ....................................................... &v-private ...


(make-variable-buffer-local 'folding-mode)
(set-default 'folding-mode nil)

(defvar folding-narrow-placeholder nil
  "Internal. Mark where \"%n\" used to be in `mode-line-format'.
Must be nil.")

(defvar folding-bottom-mark nil
  "Internal marker of the true bottom of a fold.")


(defvar folding-bottom-regexp nil
  "Internal. Regexp marking the bottom of a fold.")


(defvar folding-regexp nil
  "Internal. Regexp for hunting down the `folding-top-mark' even in comments.")

(defvar folding-secondary-top-mark nil
  "Internal. Additional stuff that can be inserted as part of a top marker.")


(defvar folding-top-mark nil
  "Internal. The actual string marking the top of a fold.")


(defvar folding-top-regexp nil
  "Internal.
Regexp describing the string beginning a fold, possible with
leading comment thingies and like that.")


(defvar folded-file nil
  "Enter folding mode when this file is loaded.
(buffer local, use from a local variables list).")


(defvar folding-calling-original nil
  "Internal. Non-nil when original mouse binding is executed.")

(defvar folding-narrow-overlays nil
  "Internal. Keep the list of overlays.")
(make-variable-buffer-local 'folding-narrow-overlays)


(defcustom folding-allow-overlays nil
  "*If non-nil use overlay code. If nil, then selective display is used."
  :type 'boolean  :group 'folding)

;;}}}
;;{{{ setup: user config

;;; ........................................................ &v-Config ...

;; Q: should this inherit mouse-yank-at-point's value? maybe not.
(defvar folding-mouse-yank-at-point t
  "If non-nil, mouse activities are done at point instead of 'mouse cursor'.
Behaves like `mouse-yank-at-point'.")


(defcustom folding-folding-on-startup t
  "*If non-nil, buffers are folded when starting Folding mode."
  :type 'boolean  :group 'folding)

(defcustom folding-internal-margins 1
  "*Number of blank lines left next to fold mark when tidying folds.

This variable is local to each buffer.  To set the default value for all
buffers, use `set-default'.

When exiting a fold, and at other times, `folding-tidy-inside' is invoked
to ensure that the fold is in the correct form before leaving it.  This
variable specifies the number of blank lines to leave between the
enclosing fold marks and the enclosed text.

If this value is nil or negative, no blank lines are added or removed
inside the fold marks.  A value of 0 (zero) is valid, meaning leave no
blank lines.

See also `folding-tidy-inside'."
  :type 'boolean  :group 'folding)

(make-variable-buffer-local 'folding-internal-margins)

(defvar folding-mode-string " Fld"
  "Buffer-local variable that hold the fold depth description.")

(set-default 'folding-mode-string " Fld")

;; Sets `folding-mode-string' appropriately.  This allows the Folding mode
;; description in the mode line to reflect the current fold depth.

(defconst folding-inside-string " "      ; was ' inside ',
  "Mode line addition to show 'inside' levels of fold.")

(defcustom folding-inside-mode-name "Fld"
  "*Mode line addition to show inside levels of 'fold' ."
  :type 'string  :group 'folding)


(defcustom folding-check-folded-file-function 'folding-check-folded
  "*Function that return t or nil after examining if the file is folded."
  :type 'function  :group 'folding)

(defcustom folding-check-allow-folding-function 'folding-check-if-folding-allowed
  "*Function that return t or nil after deciding if automatic folding."
  :type 'function  :group 'folding)

(defcustom folding-mode-string "Fld"
  "*The minor mode string displayed when mode is on."
  :type 'string  :group 'folding)

(defcustom folding-mode-hook-no-regexp "RMAIL"
  "*Regexp which disable automatic folding mode turn on for certain files."
  :type 'string  :group 'folding)


;;; ... ... ... ... ... ... ... ... ... ... ... ... ... .... &v-tables ...

(defcustom folding-behave-table
  '((close      folding-hide-current-entry)
    (open       folding-show-current-entry)              ; Could also be `folding-shift-in'.
    (up         folding-shift-out)
    (other      folding-mouse-call-original)
    )
  "*Table of of logical commands and their associated functions.
If you want fold to behave like `folding-shift-in', when it 'open' a fold, you just
change the function entry in this table.

Table form:
  '( (LOGICAL-ACTION  CMD) (..) ..)"
  :type '(repeat
	  (symbol   :tag "logical action")
	  (function :tag "callback")
	  )
  :group 'folding
  )


;;; ... ... ... ... ... ... ... ... ... ... ... ... ... ..... &v-marks ...


(defvar folding-mode-marks-alist nil
  "List of (major-mode . fold mark) default combinations to use.
When Folding mode is started, the major mode is checked, and if there
are fold marks for that major mode stored in `folding-mode-marks-alist',
those marks are used by default.  If none are found, the default values
of \"{{{ \" and \"}}}\" are used.

Use function  `folding-add-to-marks-list' to add more fold marks. The function
also explains the alist use in details.")

;;}}}


;;; ########################################################### &Funcs ###

;;{{{ Folding install

(defun folding-easy-menu-define ()
  "Define folding easy menu."
  (interactive)
  (easy-menu-define
   folding-mode-menu
   (if (boundp 'xemacs-logo)
       nil
     (list folding-mode-map))
   "Folding menu"
   (list
    folding-mode-menu-name
    ["Enter Fold"			folding-shift-in		t]
    ["Exit Fold"			folding-shift-out		t]
    ["Show Fold"			folding-show-current-entry		t]
    ["Hide Fold"			folding-hide-current-entry		t]
    "----"
    ["Show Whole Buffer"		folding-open-buffer		t]
    ["Fold Whole Buffer"		folding-whole-buffer		t]
    ["Show subtree"			folding-show-current-subtree	t]
    ["Hide subtree"			folding-hide-current-subtree	t]
    ["Display fold name"		folding-display-name		t]
    "----"
    ["Move previous"			folding-previous-visible-heading	t]
    ["Move next"			folding-next-visible-heading	t]
    ["Pick fold"			folding-pick-move			t]
    "----"
    ["Foldify Region"			folding-folding-region	t]
    ["Open or close folds in region"	folding-region-open-close	t]
    ["Open folds to top level"		folding-show-all		t]
    "----"
    ["Comment text in fold"		folding-comment-fold	t]
    ["Convert for printing(temp buffer)" folding-convert-buffer-for-printing t]
    ["Convert to major mode folds"	folding-convert-to-major-folds t]
    ["Move comments inside folds in region" fold-all-comment-blocks-in-region t]
    "----"
    ["Folding mode off"			folding-mode		t]
    )))


;;; ----------------------------------------------------------------------
;;;
(defun folding-install  ()
  "Install folding"
  (interactive)

  ;; .................................................... make keymaps ...

  (unless folding-mode-map
    (setq folding-mode-map	    (make-sparse-keymap)))

  (unless folding-mode-prefix-map
    (setq folding-mode-prefix-map   (make-sparse-keymap)))

    (if (listp folding-default-keys-function)
	(mapcar 'funcall folding-default-keys-function)
      (funcall folding-default-keys-function))

    (funcall folding-default-mouse-keys-function)


  (folding-easy-menu-define)

  (define-key folding-mode-map folding-mode-prefix-key folding-mode-prefix-map)

  ;; .............................................. install minor mode ...

  ;; Install the keymap into `minor-mode-map-alist'.  The keymap will
  ;; be activated as soon as the variable `folding-mode' is set to
  ;; non-nil.

  (let ((elt (assq 'folding-mode minor-mode-map-alist)))
    ;;  Always remove old map before adding new definitions.
    (if elt
	(setq minor-mode-map-alist
	      (delete elt minor-mode-map-alist)))
    (push (cons 'folding-mode folding-mode-map) minor-mode-map-alist))


  ;;  Update minor-mode-alist
  (or (assq 'folding-mode minor-mode-alist)
      (push '(folding-mode folding-mode-string) minor-mode-alist))


  ;;  Needed for XEmacs
  (or (fboundp 'buffer-disable-undo)
      (fset 'buffer-disable-undo (symbol-function 'buffer-flush-undo)))

  )

;;}}}

;;{{{ code: misc

;;; ............................................................ &misc ...

;;; ----------------------------------------------------------------------
;;;
(defsubst folding-get-mode-marks (&optional mode)
  "Return fold markers for MODE. default is for current `major-mode'.

Return:
  \(beg-marker end-marker\)"
  (interactive)
  (let* (elt
         )
    (unless (setq elt (assq (or mode major-mode) folding-mode-marks-alist))
      (error "*err: current mode not in `folding-mode-marks-alist'"))
    (list (nth 1 elt) (nth 2 elt) (nth 3 elt))
    ))


;;; ----------------------------------------------------------------------
;;;
(defun folding-region-has-folding-marks-p (beg end)
  "Check is there is fold mark at BEG and END."
  (save-excursion
    (goto-char beg)
    (when (memq (folding-mark-look-at) '(1 11))
      (goto-char end)
      (memq (folding-mark-look-at) '(end end-in)))))

;;; ----------------------------------------------------------------------
;;; - Thumb rule: because "{{{" if more meaningfull, all returns values
;;;   are of type integerp if it is found.
;;;
(defun folding-mark-look-at (&optional mode)
  "Check status of current line. Does it contain fold mark?.

MODE

 'move      move over fold mark

Return:

  0 1       numberp, line has fold begin mark
	    0 = closed, 1 = open,
            11 = open, we're inside fold, and this is top marker

  'end      end mark

  'end-in   end mark, inside fold, floor marker

  nil       no fold marks .."
  (let* ((marks  (folding-get-mode-marks))
         (stack  folding-stack)
         (bm     (regexp-quote (nth 0 marks))) ;begin mark
         (em     (concat "^[ \t\n]" (regexp-quote  (nth 1 marks))))
	 ret
	 point
         )

    (save-excursion
      (beginning-of-line)

      (cond
       ((looking-at (concat "^[ \t\n]*" bm))
	(setq point (point))

        (cond
         ((looking-at (concat "^[ \t\n]*" bm "[^\r\n]*\r"))  ;; closed
          (setq ret 0))
         (t                                          ;; open fold marker
          (goto-char (point-min))
          (cond
           ((and stack                               ;; we're inside fold
                 (looking-at (concat "[ \t\n]*" bm)) ;; allow spaces
                 )
            (setq ret 11)
	    )
           (t
            (setq ret 1)
	    )))))

       ((looking-at em)
	(setq point (point))

        ;; - The stack is a list if we've entered inside fold. There
        ;;   is no text after fold END mark
        ;; - At bol  ".*\n[^\n]*" doesn't work but "\n[^\n]*" at eol does??

        (cond
         ((progn
            (end-of-line)
            (or (and stack (eobp))      ;normal ending
                (and stack              ;empty neewlines only, no text ?
                     (not (looking-at "\n[^ \t\n]*"))
                     )))
          (setq ret 'end-in)
	  )
         (t                             ;all rest are newlines
          (setq ret 'end)
	  )))
       ))

    (cond
     ((and mode point)
      (goto-char point)

      ;;  This call breaks if there is no marks on the point,
      ;;  because there is no parametesr 'nil t' in call.
      ;;  --> there is error in this fucntion if that happens.

      (beginning-of-line)
      (re-search-forward (concat bm "\\|" em))
      (backward-char 1)
      ))

    ret
    ))


;;; ----------------------------------------------------------------------
;;;
(defun folding-act (action &optional event)
  "Execute logical ACTION command.

References:
  `folding-behave-table'"
  (let* ((elt (assoc action folding-behave-table)))
    (if elt
        (funcall (nth 1 elt) event)
      (error "Folding mode (folding-act): Unknown action %s" action))))



;;; ----------------------------------------------------------------------
;;;
(defun folding-region-open-close (beg end &optional close)
  "Open all folds inside region BEG END. Close if optional CLOSE is non-nil."
  (interactive "r\nP")
  (let* ((func (if (null close)
		   'folding-show-current-entry
		 'folding-hide-current-entry))
         tmp
         )
    (save-excursion
      ;;   make sure the beg is first.
      (if (> beg end)                  ;swap order
          (setq  tmp beg  beg end   end tmp))
      (goto-char beg)

      (while (and
	      ;;   the folding-show-current-entry/hide will move point
	      ;;   to beg-of-line So we must move to the end of
	      ;;   line to continue search.
	      (if (and close
		       (eq 0 (folding-mark-look-at))) ;already closed ?
		  t
		(funcall func)
		(end-of-line)
		t)
	      (folding-next-visible-heading)
	      (< (point) end)))
        )))

;;; ----------------------------------------------------------------------
;;;
(defun folding-hide-current-subtree  ()
  "Call `folding-show-current-subtree' with argument 'hide."
  (interactive)
  (folding-show-current-subtree 'hide))

;;; ----------------------------------------------------------------------
;;;
(defun folding-show-current-subtree (&optional hide)
  "Show or HIDE all folds inside current fold.
Point must be over beginning fold mark."
  (interactive "P")
  (let* ((stat  (folding-mark-look-at 'move))
	 (beg   (point))
         end
         )
    (cond
     ((memq stat '(0 1 11))		;It's BEG fold

      (when (eq 0 stat)			;it was closed
	(folding-show-current-entry)
	(goto-char beg))		;folding-pick-move needs point at fold

      (save-excursion
	(if (folding-pick-move)
	    (setq end (point))))

      (if (and beg end)
          (folding-region-open-close beg end hide))
      )
     (t
      (if (interactive-p)
	  (message "point is not at fold beginnning."))))))


;;; ----------------------------------------------------------------------
;;;
(defun folding-display-name ()
  "Show current active fold name."
  (interactive)
  (let* ((pos    (folding-find-folding-mark))
         name
         )
    (when pos
      (save-excursion
        (goto-char pos)
        (if (looking-at ".*[{]+")       ;Drop "{" mark away.
            (setq pos (match-end 0)))
        (setq name (buffer-substring
                    pos
                    (progn
                      (end-of-line)
                      (point))))))
    (if name
        (message (format "fold:%s" name)))

    ))

;;}}}
;;{{{ code: events

;;; .......................................................... &events ...

;;; ----------------------------------------------------------------------
;;;
;;;
(defun folding-event-posn (act event)
  "According to ACT read mouse EVENT struct and return data from it.
Event must be simple click, no dragging.

ACT
  'mouse-point  return the 'mouse cursor' point
  'window       return window pointer
  'col-row      return list (col row)"
  (cond
   ((not folding-xemacs-p)
    ;; short Description of FSF mouse event
    ;;
    ;; EVENT : (mouse-3 (#<window 34 on *scratch*> 128 (20 . 104) -23723628))
    ;; event-start : (#<window 34 on *scratch*> 128 (20 . 104) -23723628))
    ;;                                          ^^^MP
    ;; mp = mouse point
    (let* ((el (event-start event))
           )
      (cond
       ((eq act 'mouse-point)
        (nth 1 el))                     ;is there macro for this ?
       ((eq act 'window)
        (posn-window el))
       ((eq act 'col-row)
        (posn-col-row el))
       (t
        (error "Unknown request" act)
        ))
      ))

   (folding-xemacs-p
    (cond
     ((eq act 'mouse-point)
      (event-point event))
     ((eq act 'window)
      (event-window event))
     ;; Must be tested! (However, it's not used...)
     ((eq act 'col-row)
      (list (event-x event) (event-y event)))
     (t
      (error "Unknown request" act))))

   (t
    (error "This version of Emacs can't handle events."))))


;;; ----------------------------------------------------------------------
;;;
;;;
(defmacro folding-mouse-yank-at-p ()
  "Check is user use \"yank at mouse point\" feature.

Please see the variable `folding-mouse-yank-at-point'."
  'folding-mouse-yank-at-point)

;;; ----------------------------------------------------------------------
;;;
;;;
(defun folding-mouse-point (&optional event)
  "Return mouse's working point. Optional EVENT is mouse click.
When used on XEmacs, return nil if no character was under the mouse."
  (if (or (folding-mouse-yank-at-p)
          (null event))
      (point)
    (folding-event-posn 'mouse-point event)))

;;}}}

;;{{{ code: hook
;;; .................................................... hook-handling ...

(defun folding-is-hooked ()
  "Check if folding hooks are installed."
  (and (memq 'folding-mode-write-file write-file-hooks)
       (memq 'folding-mode-find-file  find-file-hooks)))

(defun folding-uninstall-hooks ()
  "Remove hooks set by folding."
  (interactive)
  (remove-hook 'write-file-hooks 'folding-mode-write-file)
  (remove-hook 'find-file-hooks  'folding-mode-find-file))

(defun folding-install-hooks ()
  "Install folding hooks."
  (interactive)
  (folding-mode-add-find-file-hook)
  (or (memq 'folding-mode-write-file write-file-hooks)
      (add-hook 'write-file-hooks 'folding-mode-write-file 'end)))

(defun folding-keep-hooked ()
  "Make sure hooks are in their places."
  (unless (folding-is-hooked)
    (folding-uninstall-hooks)
    (folding-install-hooks)))

;;}}}
;;{{{ code: Mouse handling

;;; ........................................................... &mouse ...


;;; ----------------------------------------------------------------------
;;;
(defun folding-mouse-call-original (&optional event)
  "Execute original mouse function using mouse EVENT.

Do nothing if original function does not exist.

Does nothing when called by a function which has earlier been called
by us.

Sets global:
  `folding-calling-original'"
  (interactive "@e")  ;; Was "e"

  ;; Without the following test we could easily end up in a endelss
  ;; loop in case we would call a function which would call us.
  ;;
  ;; (An easy constructed example is to bind the function
  ;; `folding-mouse-context-sensitive' to the same mouse button both in
  ;; `folding-mode-map' and in the global map.)

  (if folding-calling-original
      nil
    (setq folding-calling-original t)      ;; `folding-calling-original' is global
    (unwind-protect
        (progn
          (or event
              (setq event last-input-event))
          (let (mouse-key)
            (cond
             ((not folding-xemacs-p)
              (setq mouse-key (make-vector 1 (car event))))
             (folding-xemacs-p
              (setq mouse-key
                    (vector
                     (append (event-modifiers event)
                             (list (intern (format "button%d"
                                                   (event-button event))))))))
             (t
              (error "This version of Emacs can't handle events.")))

            ;; Test string: http://www.csd.uu.se/~andersl
            ;;              andersl@csd.uu.se
            ;; (I have `ark-goto-url' bound to the same key as
            ;; this function.)
	    ;;
            ;; turn off folding, so that we can see the real
            ;; fuction behind it.
            ;;
            ;; We have to restore the current buffer, otherwise the
            ;; let* won't be able to restore the old value of
            ;; folding-mode.  In my environment, I have bound a
            ;; function which starts mail when I click on an e-mail
            ;; address.  When returning, the current buffer has
            ;; changed.

            (let* ((folding-mode nil)
                   (orig-buf (current-buffer))
                   (orig-func (key-binding mouse-key))
		   )
              ;; call only if exist
              (when orig-func
		;; Check if the original function has arguments. If
		;; it does, call it with the event as argument.
		(unwind-protect
		    (progn
		      (setq this-command orig-func)
		      (call-interactively orig-func)

;;; #untested, but included here for furher reference
;;;		    (cond
;;;		     ((not (string-match "mouse" (symbol-name orig-func)))
;;;		      (call-interactively orig-func))
;;;			((string-match "^mouse" (symbol-name orig-func))
;;;			 (funcall orig-func event)
;;;			 )
;;;			(t
;;;			 ;;  Some other package's mouse command,
;;;			 ;;  should we do something speacial here for
;;;			 ;;  somelbody?
;;;			 (funcall orig-func event)
;;;			 ))
;;;
		      )
		  (set-buffer orig-buf))))))
      ;; This is always executed, even if the above generates an error.
      (setq folding-calling-original nil))))

;;; ----------------------------------------------------------------------
;;;
(defun folding-mouse-context-sensitive (event)
  "Perform some operation depending on the context of the mouse pointer.
EVENT is mouse event.

The variable `folding-behave-table' contains a mapping between contexts and
operations to perform.

The following contexts can be handled (They are named after the
natural operation to perform on them):

    open   -   A folded fold.
    close  -   An open fold, which isn't the one current topmost one.
    up     -   The topmost visible fold.
    other  -   Anything else.

Note that the `pointer' can be either the buffer point, or the mouse
pointer depending in the setting of the user option
`folding-mouse-yank-at-point'."
  (interactive "e")
  (let* (
         ;;  - Get mouse cursor point, or point
         (point (folding-mouse-point event))
         state
         )
    (if (null point)
        ;; The user didn't click on any text.
        (folding-act 'other event)

      (save-excursion
	(goto-char point)
	(setq state (folding-mark-look-at)))

      (cond
       ((eq state 0)
        (folding-act 'open event))
       ((eq state 1)
        (folding-act 'close event))
       ((eq state 11)
        (folding-act 'up event))
       ((eq 'end state)
        (folding-act 'close))
       ((eq state 'end-in)
        (folding-act 'up event))
       (t
        (folding-act 'other event))
       ))))


;;; ----------------------------------------------------------------------
;;; #not used, the pick move handles this too
(defun folding-mouse-move (event)
  "Move down if sitting on fold mark using mouse EVENT.

Original function behind the mouse is called if no FOLD action wasn't
taken."
  (interactive "e")
  (let* (
         ;;  - Get mouse cursor point, or point
         (point (folding-mouse-point event))
         state
         )
    (save-excursion
      (goto-char point)
      (beginning-of-line)
      (setq state (folding-mark-look-at)))

    (cond
     ((not (null state))
      (goto-char point)
      (folding-next-visible-heading) t)
     (t
      (folding-mouse-call-original event)
      ))))

;;; ----------------------------------------------------------------------
;;;
(defun folding-mouse-pick-move (event)
  "Pick movement if sitting on beg/end fold mark using mouse EVENT.
If mouse if at the `beginning-of-line' point, then always move up.

Original function behind the mouse is called if no FOLD action wasn't
taken."
  (interactive "e")
  (let* (
         ;;  - Get mouse cursor point, or point
         (point (folding-mouse-point event))
         state
         )
    (save-excursion
      (goto-char point)
      (setq state (folding-mark-look-at)))

    (cond
     ((not (null state))
      (goto-char point)
      (if (= point
	     (save-excursion (beginning-of-line) (point))
	     )
          (folding-previous-visible-heading)
        (folding-pick-move)))
     (t
      (folding-mouse-call-original event)
      ))))

;;}}}
;;{{{ code: engine

;;; ......................................................................

(defun folding-set-mode-line ()
  (if (null folding-stack)
      (kill-local-variable 'folding-mode-string)
    (make-local-variable 'folding-mode-string)
    (setq folding-mode-string
          (if (eq 'folded (car folding-stack))
              (concat
               folding-inside-string "1" folding-inside-mode-name)
            (concat
             folding-inside-string
             (int-to-string (length folding-stack))
             folding-inside-mode-name)))))

;;; ----------------------------------------------------------------------
;;;
(defun folding-clear-stack ()
  "Clear the fold stack, and release all the markers it refers to."
  (let ((stack folding-stack))
    (setq folding-stack nil)
    (while (and stack (not (eq 'folded (car stack))))
      (set-marker (car (car stack)) nil)
      (set-marker (cdr (car stack)) nil)
      (setq stack (cdr stack)))))


;;; ----------------------------------------------------------------------
;;;
(defun folding-check-if-folding-allowed ()
  "Return non-nil when buffer allowed to be folded automatically.
When buffer is loaded it may not be desirable to fold it immediately,
because the file may be too large, or it may contain fold marks, that
really are not _real_ folds. (Eg. RMAIL saved files may have the
marks)

This function returns t, if it's okay to proceed checking the fold status
of file. Returning nil means that folding should not touch this file.

The variable `folding-check-allow-folding-function' normally contains this
function.  Change the variable to use your own scheme."
  ;;  Do not fold these files
  (null (string-match folding-mode-hook-no-regexp (buffer-name))))



;;; ----------------------------------------------------------------------
;;;
(defun folding-mode-find-file ()
  "One of the funcs called whenever a `find-file' is successful.
It checks to see if `folded-file' has been set as a buffer-local
variable, and automatically starts Folding mode if it has.

This allows folded files to be automatically folded when opened.

To make this hook effective, the symbol `folding-mode-find-file-hook'
should be placed at the end of `find-file-hooks'.  If you have
some other hook in the list, for example a hook to automatically
uncompress or decrypt a buffer, it should go earlier on in the list.

See also `folding-mode-add-find-file-hook'."
   (let* ((check-fold folding-check-folded-file-function)
          (allow-fold folding-check-allow-folding-function)
          )
     ;;  Turn mode on only if it's allowed
     (if (funcall allow-fold)
         (or (and (and check-fold (funcall check-fold))
                  (folding-mode 1))
             (and (assq 'folded-file (buffer-local-variables))
                  folded-file
                  (folding-mode 1)
                  (kill-local-variable 'folded-file)
                  )))))


;;; ----------------------------------------------------------------------
;;;
(defun folding-mode-add-find-file-hook ()
  "Append `folding-mode-find-file-hook' to the list `find-file-hooks'.

This has the effect that afterwards, when a folded file is visited, if
appropriate Emacs local variable entries are recognized at the end of
the file, Folding mode is started automatically.

If `inhibit-local-variables' is non-nil, this will not happen regardless
of the setting of `find-file-hooks'.

To declare a file to be folded, put `folded-file: t' in the file's
local variables.  eg., at the end of a C source file, put:

/*
Local variables:
folded-file: t
*/

The local variables can be inside a fold."
  (interactive)
  (or (memq 'folding-mode-find-file find-file-hooks)
      (add-hook 'find-file-hooks 'folding-mode-find-file 'end)))


;;; ----------------------------------------------------------------------
;;;
(defun folding-mode-write-file ()
  "Folded files must be controlled by folding before saving.
This function turns on the folding mode if it is not activated.
It prevents 'binary pollution' upon save."
  (let* ((check-func  folding-check-folded-file-function)
          (no-re      folding-mode-hook-no-regexp)
          (bn         (or (buffer-name) ""))
          )
    (if (and (not       (string-match no-re bn))
             (boundp    'folding-mode)
             (null      folding-mode)
             (and check-func (funcall check-func)))
        (progn
          ;;  When folding mode is turned on it also 'folds' whole
          ;;  buffer... can't avoid that, since it's more important
          ;;  to save safely
          (folding-mode 1)))
    nil                                 ;hook returns nil, good habit
    ))


;;; ----------------------------------------------------------------------
;;;
(defun folding-check-folded ()
  "Function to determine if this file is in folded form."
  (let* (;;  Could use folding-top-regexp , folding-bottom-regexp ,
         ;;  folding-regexp But they are not available at load time.
         (folding-re1 "^.?.?.?{{{")
         (folding-re2 "[\r\n].*}}}")
         )
    (if (save-excursion
          (goto-char (point-min))
          ;;  If we found both, we assume file is folded
          (and (re-search-forward folding-re1 nil t)
               (re-search-forward folding-re2 nil t)
               ))
        t nil
        )))

;;}}}

;;{{{ code: Folding mode

;;; ............................................................ &main ...

(defun folding-mode (&optional arg inter)
  "A folding-editor-like minor mode. ARG INTER.

These are the basic commands that Folding mode provides:

\\{folding-mode-map}

folding-convert-buffer-for-printing:  `\\[folding-convert-buffer-for-printing]'
     Makes a ready-to-print, formatted, unfolded copy in another buffer.

     Read the documentation for the above functions for more information.

Overview

    Folds are a way of hierarchically organizing the text in a file, so that
    the text can be viewed and edited at different levels.  It is similar to
    Outline mode in that parts of the text can be hidden from view.  A fold
    is a region of text, surrounded by special \"fold marks\", which act
    like brackets, grouping the text.  Fold mark pairs can be nested, and
    they can have titles.  When a fold is folded, the text is hidden from
    view, except for the first line, which acts like a title for the fold.

    Folding mode is a minor mode, designed to cooperate with many other
    major modes, so that many types of text can be folded while they are
    being edited (eg., plain text, program source code, Texinfo, etc.).

Folding-mode function

    If Folding mode is not called interactively (`(interactive-p)' is nil),
    and it is called with two or less arguments, all of which are nil, then
    the point will not be altered if `folding-folding-on-startup' is set and
    `folding-whole-buffer' is called.  This is generally not a good thing, as
    it can leave the point inside a hidden region of a fold, but it is
    required if the local variables set \"mode: folding\" when the file is
    first read (see `hack-local-variables').

    Not that you should ever want to, but to call Folding mode from a
    program with the default behavior (toggling the mode), call it with
    something like `(folding-mode nil t)'.

Fold marks

    For most types of folded file, lines representing folds have \"{{{\"
    near the beginning.  To enter a fold, move the point to the folded line
    and type `\\[folding-shift-in]'.  You should no longer be able to see the rest
    of the file, just the contents of the fold, which you couldn't see
    before.  You can use `\\[folding-shift-out]' to leave a fold, and you can enter
    and exit folds to move around the structure of the file.

    All of the text is present in a folded file all of the time.  It is just
    hidden.  Folded text shows up as a line (the top fold mark) with \"...\"
    at the end.  If you are in a fold, the mode line displays \"inside n
    folds Narrow\", and because the buffer is narrowed you can't see outside
    of the current fold's text.

    By arranging sections of a large file in folds, and maybe subsections in
    sub-folds, you can move around a file quickly and easily, and only have
    to scroll through a couple of pages at a time.  If you pick the titles
    for the folds carefully, they can be a useful form of documentation, and
    make moving though the file a lot easier.  In general, searching through
    a folded file for a particular item is much easier than without folds.

Managing folds

    To make a new fold, set the mark at one end of the text you want in the
    new fold, and move the point to the other end.  Then type
    `\\[folding-folding-region]'.  The text you selected will be made into a fold,
    and the fold will be entered.  If you just want a new, empty fold, set
    the mark where you want the fold, and then create a new fold there
    without moving the point.  Don't worry if the point is in the middle of
    a line of text, `folding-folding-region' will not break text in the middle of
    a line.  After making a fold, the fold is entered and the point is
    positioned ready to enter a title for the fold.  Do not delete the fold
    marks, which are usually something like \"{{{\" and \"}}}\".  There may
    also be a bit of fold mark which goes after the fold title.

    If the fold markers get messed up, or you just want to see the whole
    unfolded file, use `\\[folding-open-buffer]' to unfolded the whole file, so
    you can see all the text and all the marks.  This is useful for
    checking/correcting unbalanced fold markers, and for searching for
    things.  Use `\\[folding-whole-file]' to fold the buffer again.

    `folding-shift-out' will attempt to tidy the current fold just before exiting
    it.  It will remove any extra blank lines at the top and bottom,
    \(outside the fold marks).  It will then ensure that fold marks exists,
    and if they are not, will add them (after asking).  Finally, the number
    of blank lines between the fold marks and the contents of the fold is
    set to 1 (by default).

Folding package customisations

    If the fold marks are not set on entry to Folding mode, they are set to
    a default for current major mode, as defined by `folding-mode-marks-alist'
    or to \"{{{ \" and \"}}}\" if none are specified.

    To bind different commands to keys in Folding mode, set the bindings in
    the keymap `folding-mode-map'.

    The hooks `folding-mode-hook' and `<major-mode-name>-folding-hook' are
    called before folding the buffer and applying the key bindings in
    `folding-mode-map'.  This is a good hook to set extra or different key
    bindings in `folding-mode-map'.  Note that key bindings in
    `folding-mode-map' are only examined just after calling these hooks; new
    bindings in those maps only take effect when Folding mode is being
    started.  The hook `folding-load-hook' is called when Folding mode is
    loaded into Emacs.

Mouse behavior

    If you want folding to detect point of actual mouse click, please see
    variable `folding-mouse-yank-at-p'.

    To customise the mouse actions, look at `folding-behave-table'.
"
  (interactive)
;;  (folding-keep-hooked)                  ;set hooks if not there

  (let ((new-folding-mode
         (if (not arg) (not folding-mode)
           (> (prefix-numeric-value arg) 0)))
        )

    (or (eq new-folding-mode
            folding-mode)
        (if folding-mode
            (progn
              ;; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ progn ^^^
              ;; turn off folding
              (if (null (folding-use-overlays-p))
                  (setq selective-display nil))

              (folding-clear-stack)
              (folding-narrow-to-region nil nil)
              (folding-subst-regions (list 1 (point-max)) ?\r ?\n)

              ;; Restore "%n" (Narrow) in the mode line
              (setq mode-line-format
                    (mapcar
                     (function
                      (lambda (item)
                        (if (equal item 'folding-narrow-placeholder)
                            "%n" item)))
                     mode-line-format))

              )
          ;; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ else ^^^

          (cond
           ((folding-use-overlays-p)
            ;;  Is this Emacs specific; howabout XEmacs?
            (setq  line-move-ignore-invisible t
                   buffer-invisibility-spec   '((t . t)))
            )
           (t
            (setq selective-display t)
            (setq selective-display-ellipses t)
            ))

          (widen)
          (setq folding-narrow-overlays nil)
          (set (make-local-variable 'folding-stack) nil)
          (make-local-variable 'folding-top-mark)
          (make-local-variable 'folding-secondary-top-mark)
          (make-local-variable 'folding-top-regexp)
          (make-local-variable 'folding-bottom-mark)
          (make-local-variable 'folding-bottom-regexp)
          (make-local-variable 'folding-regexp)

          (or (and (boundp 'folding-top-regexp)
                   folding-top-regexp
                   (boundp 'folding-bottom-regexp)
                   folding-bottom-regexp)
              (let ((folding-marks (assq major-mode
                                      folding-mode-marks-alist)))
                (if folding-marks
                    (setq folding-marks (cdr folding-marks))
                  (setq folding-marks '("{{{ " "}}}")))
                (apply 'folding-set-marks folding-marks)))


          (unwind-protect
              (let ((hook-symbol (intern-soft
                                  (concat
                                   (symbol-name major-mode)
                                   "-folding-hook"))))
                (run-hooks 'folding-mode-hook)
                (and hook-symbol
                     (run-hooks hook-symbol)))
            (folding-set-mode-line)
            )


          (and folding-folding-on-startup
               (if (or (interactive-p)
                       arg
                       inter)
                   (folding-whole-buffer)
                 (save-excursion
                   (folding-whole-buffer))))


          (folding-narrow-to-region nil nil t)

          ;; Remove "%n" (Narrow) from the mode line
          (setq mode-line-format
                (mapcar
                 (function
                  (lambda (item)
                    (if (equal item "%n")
                        'folding-narrow-placeholder item)))
                 mode-line-format))
          ))
    (setq folding-mode new-folding-mode)

    (if folding-mode
	(easy-menu-add folding-mode-menu)
      (easy-menu-remove folding-mode-menu))

    ))

;;}}}


;;{{{ code: setting fold marks

;; You think those "\\(\\)" pairs are peculiar?  Me too.  Emacs regexp
;; stuff has a bug; sometimes "\\(.*\\)" fails when ".*" succeeds, but
;; only in a folded file!  Strange bug!  Must check it out sometime.

(defun folding-set-marks (top bottom &optional secondary)
  "Set the folding top and bottom mark for the current buffer.

Input:

  TOP		The topmost fold mark. Comment start + fold begin string.
  BOTTOM	The bottom fold mark Comment end + fold end string.
  SECONDARY	Usually the comment end indicator for the mode. This
		is inserted by `folding-folding-region' after the fold top mark, and is
		presumed to be put after the title of the fold.

Example:

   html-mode:

      top: \"<!-- [[[ \"
      bot: \"<!-- ]]] -->\"
      sec: \" -->\"

Notice that the top marker needs to be closed with SECONDARY comment end string.

Various regular expressions are set with this function, so don't set the
mark variables directly."
  (set (make-local-variable 'folding-top-mark)
       top)
  (set (make-local-variable 'folding-bottom-mark)
       bottom)
  (set (make-local-variable 'folding-secondary-top-mark)
       secondary)
  (set (make-local-variable 'folding-top-regexp)
       (concat "\\(^\\|\r+\\)[ \t]*"
               (regexp-quote folding-top-mark)))
  (set (make-local-variable 'folding-bottom-regexp)
       (concat "\\(^\\|\r+\\)[ \t]*"
               (regexp-quote folding-bottom-mark)))
  (set (make-local-variable 'folding-regexp)
       (concat "\\(^\\|\r\\)\\([ \t]*\\)\\(\\("
               (regexp-quote folding-top-mark)
               "\\)\\|\\("
               (regexp-quote folding-bottom-mark)
               "[ \t]*\\(\\)\\($\\|\r\\)\\)\\)")))

;;}}}

;;{{{ code: movement

;;; ----------------------------------------------------------------------
;;;
(defun folding-next-visible-heading (&optional direction)
  "Move up/down fold headers.
Backward if DIRECTION is non-nil returns nil if not moved = no next marker."
  (interactive)
  (let* ((bm  (nth 0 (folding-get-mode-marks)))               ;begin mark
         )
     (if direction
	 (re-search-backward (concat "^" (regexp-quote bm)) nil t)
       (re-search-forward  (concat "^" (regexp-quote bm)) nil t))))

;;; ----------------------------------------------------------------------
;;;
(defun folding-previous-visible-heading ()
  "Move upward fold headers."
  (interactive)
  (beginning-of-line)
  (folding-next-visible-heading 'backward))

;;; ----------------------------------------------------------------------
;;;
(defun folding-find-folding-mark (&optional end-fold)
  "Search backward to find beginning fold. Skips subfolds.
Optionally searches forward to find END-FOLD mark.

Return:

  nil
  point     position of fold mark"
  (let* ((elt   (folding-get-mode-marks))
         (bm    (regexp-quote (nth 0 elt))) ; markers defined for mode
         (em    (regexp-quote (nth 1 elt))) ; markers defined for mode
         (re    (concat "^" bm "\\|^" em ))
         (count 0)
         stat
         moved

         )
    (save-excursion

      (cond
       (end-fold

	(folding-end-of-line)

        ;; We must skip over inner folds
        (while (and (null moved)
                    (re-search-forward re nil t))
          (setq stat (folding-mark-look-at))
          (cond
           ((symbolp stat)
            (setq count (1- count))
            (if (< count 0)             ;0 or less means no middle folds
                (setq moved t)))
           ((memq stat '(1 11))                 ;BEG fold
            (setq count (1+ count))
            ))) ;; end while

        (when moved
          (forward-char -3)
          (setq moved (point)))

        )

       (t
        (while (and (null moved)
                    (re-search-backward  re nil t))

          (setq stat (folding-mark-look-at))
          (cond
           ((memq stat '(1 11))
            (setq count (1- count))
            (if (< count 0)             ;0 or less means no middle folds
                (setq moved (point))))
           ((symbolp stat)
            (setq count (1+ count))
            )))

        (when moved ;What's the result
          (forward-char 3)
          (setq moved (point)))

        )))
    moved
    ))

;;; ----------------------------------------------------------------------
;;;
(defun folding-pick-move ()
  "Pick the logical movement on fold mark.
If at the end of fold, then move to the beginning and vice versa.

If placed over closed fold moves to the next fold. When no next
folds are visible, stops moving.

Return:
 t      if moved"
  (interactive)
  (let* ((elt   (folding-get-mode-marks))
         (bm    (nth 0 elt))              ; markers defined for mode
         (stat  (folding-mark-look-at))
         moved
         )
    (cond
     ((eq 0 stat)                       ;closed fold
      (when (re-search-forward  (concat "^" (regexp-quote bm)) nil t)
	(setq moved t)
	(forward-char 3)))

     ((symbolp stat)                    ;End fold
      (setq moved (folding-find-folding-mark)))

     ((integerp stat)                   ;Beg fold
      (setq moved (folding-find-folding-mark 'end-fold))
      ))

    (if (integerp moved)
	(goto-char moved))

    moved
    ))




;;; ----------------------------------------------------------------------
;;
(defun folding-forward-char (&optional arg)
  "Move point right ARG characters, skipping hidden folded regions.
Moves left if ARG is negative.  On reaching end of buffer, stop and
signal error."
  (interactive "p")
  (folding-preserve-active-region)
  (if (eq arg 1)
      ;; Do it a faster way for arg = 1.
      (if (eq (following-char) ?\r)
          (let ((saved (point))
                (inhibit-quit t))
            (end-of-line)
            (if (not (eobp))
                (forward-char)
              (goto-char saved)
              (error "End of buffer")))
        ;; `forward-char' here will do its own error if (eobp).
        (forward-char))
    (if (> 0 (or arg (setq arg 1)))
        (folding-backward-char (- arg))
      (let (goal saved)
        (while (< 0 arg)
          (skip-chars-forward "^\r" (setq goal (+ (point) arg)))
          (if (eq goal (point))
              (setq arg 0)
            (if (eobp)
                (error "End of buffer")
              (setq arg (- goal 1 (point))
                    saved (point))
              (let ((inhibit-quit t))
                (end-of-line)
                (if (not (eobp))
                    (forward-char)
                  (goto-char saved)
                  (error "End of buffer"))))))))))

;;; ----------------------------------------------------------------------
;;;
(defun folding-backward-char (&optional arg)
  "Move point left ARG characters, skipping hidden folded regions.
Moves right if ARG is negative.  On reaching beginning of buffer, stop
and signal error."
  (interactive "p")
  (folding-preserve-active-region)
  (if (eq arg 1)
      ;; Do it a faster way for arg = 1.
      ;; Catch the case where we are in a hidden region, and bump into a \r.
      (if (or (eq (preceding-char) ?\n)
              (eq (preceding-char) ?\r))
          (let ((pos (1- (point)))
                (inhibit-quit t))
            (forward-char -1)
            (beginning-of-line)
            (skip-chars-forward "^\r" pos))
        (forward-char -1))
    (if (> 0 (or arg (setq arg 1)))
        (folding-forward-char (- arg))
      (let (goal)
        (while (< 0 arg)
          (skip-chars-backward "^\r\n" (max (point-min)
                                            (setq goal (- (point) arg))))
          (if (eq goal (point))
              (setq arg 0)
            (if (bobp)
                (error "Beginning of buffer")
              (setq arg (- (point) 1 goal)
                    goal (point))
              (let ((inhibit-quit t))
                (forward-char -1)
                (beginning-of-line)
                (skip-chars-forward "^\r" goal)))))))))



;;; ----------------------------------------------------------------------
;;;
(defun folding-end-of-line (&optional arg)
  "Move point to end of current line, but before hidden folded region.
ARG is line count.

Has the same behavior as `end-of-line', except that if the current line
ends with some hidden folded text (represented by an ellipsis), the
point is positioned just before it.  This prevents the point from being
placed inside the folded text, which is not normally useful."
  (interactive "p")
  (folding-preserve-active-region)
  (if (or (eq arg 1)
          (not arg))
      (beginning-of-line)
    ;; `forward-line' also moves point to beginning of line.
    (forward-line (1- arg)))
  (skip-chars-forward "^\r\n"))


;;; ----------------------------------------------------------------------
;;;
(defun folding-skip-ellipsis-backward ()
  "Move the point backwards out of folded text.

If the point is inside a folded region, the cursor is displayed at the
end of the ellipsis representing the folded part.  This function checks
to see if this is the case, and if so, moves the point backwards until
it is just outside the hidden region, and just before the ellipsis.

Returns t if the point was moved, nil otherwise."
  (interactive)
  (let ((pos (point))
        result)
    (save-excursion
      (beginning-of-line)
      (skip-chars-forward "^\r" pos)
      (or (eq pos (point))
          (setq pos (point)
                result t)))
    (goto-char pos)
    result))


;;}}}

;;{{{ code: Moving in and out of folds

;;{{{ folding-shift-in

;;; ----------------------------------------------------------------------
;;;
(defun folding-shift-in (&optional noerror)
  "Open and enter the fold at or around the point.

Enters the fold that the point is inside, wherever the point is inside
the fold, provided it is a valid fold with balanced top and bottom
marks.  Returns nil if the fold entered contains no sub-folds, t
otherwise.  If an optional argument NOERROR is non-nil, returns nil if
there are no folds to enter, instead of causing an error.

If the point is inside a folded, hidden region (as represented by an
ellipsis), the position of the point in the buffer is preserved, and as
many folds as necessary are entered to make the surrounding text
visible.  This is useful after some commands eg., search commands."
  (interactive)
  (let ((goal (point)))
    (if (folding-skip-ellipsis-backward)
        (while (prog2 (beginning-of-line)
                      (folding-shift-in t)
                      (goto-char goal)))
      (let ((data (folding-show-current-entry noerror t)))
        (and data
             (progn
               (setq folding-stack
                     (if folding-stack
                         (cons (cons (point-min-marker) (point-max-marker))
                               folding-stack)
                       '(folded)))
               (folding-set-mode-line)
               (folding-narrow-to-region (car data) (nth 1 data))
               (nth 2 data)))))))

;;}}}
;;{{{ folding-shift-out

(defun folding-shift-out (&optional event)
  "Exits the current fold."
  (interactive)
  (if folding-stack
      (progn
        (folding-tidy-inside)

        (cond
         ((folding-use-overlays-p)
          (folding-subst-regions
           (list (overlay-end (car folding-narrow-overlays))
                 (overlay-start (cdr folding-narrow-overlays))) ?\n ?\r)
          ;; So point is correct in other windows.
          (goto-char (overlay-end (car folding-narrow-overlays)))
          )
         (t
          (folding-subst-regions (list (point-min) (point-max)) ?\n ?\r)
          (goto-char (point-min)) ;; So point is correct in other window
          ))

        (if (eq (car folding-stack) 'folded)
            (folding-narrow-to-region nil nil t)
          (folding-narrow-to-region (marker-position (car (car folding-stack)))
                                 (marker-position (cdr (car folding-stack))) t))
        (and (consp (car folding-stack))
             (set-marker (car (car folding-stack)) nil)
             (set-marker (cdr (car folding-stack)) nil))
        (setq folding-stack (cdr folding-stack)))
    (error "Outside all folds"))
  (folding-set-mode-line))

;;}}}
;;{{{ folding-show-current-entry

(defun folding-show-current-entry (&optional event noerror noskip)
  "Opens the fold that the point is on, but does not enter it.
Optional arg NOERROR means don't signal an error if there is no fold,
just return nil.  NOSKIP means don't jump out of a hidden region first.

Returns ((START END SUBFOLDS-P).  START and END indicate the extents of
the fold that was shown.  If SUBFOLDS-P is non-nil, the fold contains
subfolds."
  (interactive)
  (or noskip
      (folding-skip-ellipsis-backward))
  (let ((point (point))
        backward forward start end subfolds-not-p)
    (unwind-protect
        (or (and (integerp (car-safe (setq backward (folding-skip-folds t))))
                 (integerp (car-safe (setq forward (folding-skip-folds nil))))
                 (progn
                   (goto-char (car forward))
                   (skip-chars-forward "^\r\n")
                   (setq end (point))
                   (skip-chars-forward "\r\n")
                   (not (and folding-stack (eobp))))
                 (progn
                   (goto-char (car backward))
                   (skip-chars-backward "^\r\n")
                   (setq start (point))
                   (skip-chars-backward "\r\n")
                   (not (and folding-stack (bobp))))
                 (progn
                   (setq point start)
                   (setq subfolds-not-p ; Avoid holding the list through a GC.
                         (not (or (cdr backward) (cdr forward))))
                   (folding-subst-regions (append backward (nreverse forward))
                                       ?\r ?\n)
                   (list start end (not subfolds-not-p))))
            (if noerror
                nil
              (error "Not on a fold")))
      (goto-char point))))


;;}}}
;;{{{ folding-hide-current-entry


(defun folding-toggle-enter-exit ()
  "Run folding-shift-in or folding-shift-out depending on current line's contents."
  (interactive)
  (beginning-of-line)
  (let ((current-line-mark (folding-mark-look-at)))
    (if (and (numberp current-line-mark)
	     (= current-line-mark 0))
	(folding-shift-in)
      (folding-shift-out))))

(defun folding-toggle-show-hide ()
  "Run folding-show-current-entry or folding-hide-current-entry depending on current line's contents."
  (interactive)
  (beginning-of-line)
  (let ((current-line-mark (folding-mark-look-at)))
    (if (and (numberp current-line-mark)
	     (= current-line-mark 0))
	(folding-show-current-entry)
      (folding-hide-current-entry))))

(defun folding-hide-current-entry (&optional event)
  "Close the fold around the point, undo effect of `folding-show-current-entry'."
  (interactive)
  (folding-skip-ellipsis-backward)
  (let (start end)
    (if (and (integerp (setq start (car-safe (folding-skip-folds t))))
             (integerp (setq end (car-safe (folding-skip-folds nil)))))
        (if (and folding-stack
                 (or (eq start (point-min))
                     (eq end (point-max))))
            ;;(error "Cannot hide current fold")
            (folding-shift-out)
          (goto-char start)
          (skip-chars-backward "^\r\n")
          (folding-subst-regions (list start end) ?\n ?\r))
      (error "Not on a fold"))))

;;}}}
;;{{{ folding-show-all

(defun folding-show-all ()
  "Exits all folds, to the top level."
  (interactive)
  (while folding-stack
    (folding-shift-out)))

;;}}}
;;{{{ folding-goto-line

(defun folding-goto-line (line)
  "Go to LINE, entering as many folds as possible."
  (interactive "NGoto line: ")
  (folding-show-all)
  (goto-char 1)
  (and (< 1 line)
       (re-search-forward "[\n\C-m]" nil 0 (1- line)))
  (let ((goal (point)))
    (while (prog2 (beginning-of-line)
                  (folding-shift-in t)
                  (goto-char goal))))
  (folding-narrow-to-region (point-min) (point-max) t))

;;}}}

;;}}}
;;{{{ code: Searching for fold boundaries

;;{{{ folding-skip-folds

;; Skips forward through the buffer (backward if BACKWARD is non-nil)
;; until it finds a closing fold mark or the end of the buffer.  The
;; point is not moved.  Jumps over balanced folding-mark pairs on the way.
;; Returns t if the end of buffer was found in an unmatched folding-mark
;; pair, otherwise a list.
;;
;; If the point is actually on an fold start mark, the mark is ignored;
;; if it is on an end mark, the mark is noted.  This decision is
;; reversed if BACKWARD is non-nil.  If optional OUTSIDE is non-nil and
;; BACKWARD is nil, either mark is noted.
;;
;; The first element of the list is a position in the end of the closing
;; fold mark if one was found, or nil.  It is followed by (END START)
;; pairs (flattened, not a list of pairs).  The pairs indicating the
;; positions of folds skipped over; they are positions in the fold
;; marks, not necessarily at the ends of the fold marks.  They are in
;; the opposite order to that in which they were skipped.  The point is
;; left in a meaningless place.  If going backwards, the pairs are
;; (START END) pairs, as the fold marks are scanned in the opposite
;; order.
;;
;; Works by maintaining the position of the top and bottom marks found
;; so far.  They are found separately using a normal string search for
;; the fixed part of a fold mark (because it is faster than a regexp
;; search if the string does not occur often outside of fold marks),
;; checking that it really is a proper fold mark, then considering the
;; earliest one found.  The position of the other (if found) is
;; maintained to avoid an unnecessary search at the next iteration.

(defun folding-skip-folds (backward &optional outside)
  (let ((first-mark (if backward folding-bottom-mark folding-top-mark))
	(last-mark  (if backward folding-top-mark folding-bottom-mark))
	(search     (if backward 'search-backward 'search-forward))

	(depth 0)
	pairs point temp start first last
	)
    (save-excursion
      (skip-chars-backward "^\r\n")

      (unless outside
        (and (eq (preceding-char) ?\r)
             (forward-char -1))
        (if (looking-at folding-top-regexp)
            (if backward
                (setq last (match-end 1))
              (skip-chars-forward "^\r\n"))))

      (while (progn
               ;; Find last first, prevents unnecessary searching for first.
               (setq point (point))
               (or last
                   (while (and (funcall search last-mark first t)
                               (progn
                                 (setq temp (point))
                                 (goto-char (match-beginning 0))
                                 (skip-chars-backward " \t")
                                 (and (not (setq last
                                                 (if (eq (preceding-char) ?\r)
                                                     temp
                                                   (and (bolp) temp))))
                                      (goto-char temp)))))
                   (goto-char point))
               (or first
                   (while (and (funcall search first-mark last t)
                               (progn
                                 (setq temp (point))
                                 (goto-char (match-beginning 0))
                                 (skip-chars-backward " \t")
                                 (and (not (setq first
                                                 (if (eq (preceding-char) ?\r)
                                                     temp
                                                   (and (bolp) temp))))
                                      (goto-char temp))))))
               ;; Return value of conditional says whether to iterate again.
               (if (not last)
                   ;; Return from this with the result.
                   (not (setq pairs (if first t (cons nil pairs))))
                 (if (and first (if backward (> first last) (< first last)))
                     (progn
                       (goto-char first)
                       (if (eq 0 depth)
                           (setq start first
                                 first nil
                                 depth 1) ;; non-nil value, loop again.
                         (setq first nil
                               depth (1+ depth)))) ;; non-nil value, loop again
                   (goto-char last)
                   (if (eq 0 depth)
                       (not (setq pairs (cons last pairs)))
                     (or (< 0 (setq depth (1- depth)))
                         (setq pairs (cons last (cons start pairs))))
                     (setq last nil)
                     t)))))
      pairs)))

;;}}}

;;}}}
;;{{{ code: Functions that actually modify the buffer

;;{{{ folding-folding-region

(defun folding-folding-region (start end)
  "Places fold mark at the beginning and end of a specified region.
The region is specified by two arguments START and END.  The point is
left at a suitable place ready to insert the title of the fold."
  (interactive "r")
  (and (< end start)
       (setq start (prog1 end
                     (setq end start))))
  (setq end (set-marker (make-marker) end))
  (goto-char start)
  (beginning-of-line)
  (setq start (point))
  (insert-before-markers folding-top-mark)
  (let ((saved-point (point)))
    (and folding-secondary-top-mark
         (insert-before-markers folding-secondary-top-mark))
    (insert-before-markers ?\n)
    (goto-char (marker-position end))
    (set-marker end nil)
    (and (not (bolp))
         (eq 0 (forward-line))
         (eobp)
         (insert ?\n))
    (insert folding-bottom-mark)
    (insert ?\n)
    (setq folding-stack (if folding-stack
                            (cons (cons (point-min-marker)
                                        (point-max-marker))
                                  folding-stack)
                          '(folded)))
    (folding-narrow-to-region start (1- (point)))
    (goto-char saved-point)
    (folding-set-mode-line))
  (save-excursion (folding-tidy-inside)))

;;}}}
;;{{{ folding-tidy-inside

;; Note to self: The long looking code for checking and modifying those
;; blank lines is to make sure the text isn't modified unnecessarily.
;; Don't remove it again!

(defun folding-tidy-inside ()
  "Add or remove blank lines at the top and bottom of the current fold.
Also adds fold marks at the top and bottom (after asking), if they are not
there already.  The amount of space left depends on the variable
`folding-internal-margins', which is one by default."
  (interactive)
  (if buffer-read-only nil

    (if (folding-use-overlays-p)
        (goto-char (- (overlay-end (car folding-narrow-overlays)) 1))
      (goto-char (point-min)))

    (and (eolp)
         (progn (skip-chars-forward "\n\t ")
                (delete-region (point-min) (point))))
    (and (if (looking-at folding-top-regexp)
             (progn (forward-line 1)
                    (and (eobp) (insert ?\n))
                    t)
           (and (y-or-n-p "Insert missing folding-top-mark? ")
                (progn (insert (concat folding-top-mark
                                       "<Replaced missing fold top mark>"
                                       (or folding-secondary-top-mark "")
                                       "\n"))
                       t)))
         folding-internal-margins
         (<= 0 folding-internal-margins)
         (let* ((p1 (point))
                (p2 (progn (skip-chars-forward "\n") (point)))
                (p3 (progn (skip-chars-forward "\n\t ")
                           (skip-chars-backward "\t " p2) (point))))
           (if (eq p2 p3)
               (or (eq p2 (setq p3 (+ p1 folding-internal-margins)))
                   (if (< p2 p3)
                       (newline (- p3 p2))
                     (delete-region p3 p2)))
             (delete-region p1 p3)
             (or (eq 0 folding-internal-margins)
                 (newline folding-internal-margins)))))

    (if (folding-use-overlays-p)
        (goto-char  (overlay-start (cdr folding-narrow-overlays)))
      (goto-char (point-max)))

    (and (bolp)
         (progn (skip-chars-backward "\n")
                (delete-region (point) (point-max))))
    (beginning-of-line)
    (and (or (looking-at folding-bottom-regexp)
             (progn (goto-char (point-max)) nil)
             (and (y-or-n-p "Insert missing folding-bottom-mark? ")
                  (progn
                    (insert (concat "\n" folding-bottom-mark))
                    (beginning-of-line)
                    t)))
         folding-internal-margins
         (<= 0 folding-internal-margins)
         (let* ((p1 (point))
                (p2 (progn (skip-chars-backward "\n") (point)))
                (p3 (progn (skip-chars-backward "\n\t ")
                           (skip-chars-forward "\t " p2) (point))))
           (if (eq p2 p3)
               (or (eq p2 (setq p3 (- p1 1 folding-internal-margins)))
                   (if (> p2 p3)
                       (newline (- p2 p3))
                     (delete-region p2 p3)))
             (delete-region p3 p1)
             (newline (1+ folding-internal-margins)))))))

;;}}}

;;}}}
;;{{{ code: Operations on the whole buffer

;;{{{ folding-whole-buffer

(defun folding-whole-buffer ()
  "Folds every fold in the current buffer.
Fails if the fold markers are not balanced correctly.

If the buffer is being viewed in a fold, folds are repeatedly exited to
get to the top level first (this allows the folds to be tidied on the
way out).  The buffer modification flag is not affected, and this
function will work on read-only buffers."

  (interactive)
  (message "Folding buffer...")
  (let ((narrow-min (point-min))
        (narrow-max (point-max))
        folding-list
	)
    (save-excursion
      (widen)
      (goto-char 1)
      (setq folding-list (folding-skip-folds nil t))
      (narrow-to-region narrow-min narrow-max)
      (and (eq t folding-list)
           (error "Cannot fold whole buffer -- unmatched begin-fold mark"))
      (and (integerp (car folding-list))
           (error "Cannot fold whole buffer -- extraneous end-fold mark"))
      (folding-show-all)
      (widen)
      (goto-char 1)
      ;; Do the modifications forwards.
      (folding-subst-regions (nreverse (cdr folding-list)) ?\n ?\r)
      )
    (beginning-of-line)
    (folding-narrow-to-region nil nil t)
    (message "Folding buffer... done")
    ))

;;}}}
;;{{{ folding-open-buffer

(defun folding-open-buffer ()
  "Unfolds the entire buffer, leaving the point where it is.
Does not affect the buffer-modified flag, and can be used on read-only
buffers."
  (interactive)
  (message "Unfolding buffer...")
  (folding-clear-stack)
  (folding-set-mode-line)
  (unwind-protect
      (progn
        (widen)
        (folding-subst-regions (list 1 (point-max)) ?\r ?\n))
    (folding-narrow-to-region nil nil t))
  (message "Unfolding buffer... done"))

;;}}}
;;{{{ folding-convert-buffer-for-printing

(defun folding-convert-buffer-for-printing (&optional buffer pre-title post-title pad)
  "Remove folds from a buffer, for printing.

It copies the contents of the (hopefully) folded buffer BUFFER into a
buffer called `*Unfolded: <Original-name>*', removing all of the fold
marks.  It keeps the titles of the folds, however, and numbers them.
Subfolds are numbered in the form 5.1, 5.2, 5.3 etc., and the titles are
indented to eleven characters.

It accepts four arguments.  BUFFER is the name of the buffer to be
operated on, or a buffer.  nil means use the current buffer.  PRE-TITLE
is the text to go before the replacement fold titles, POST-TITLE is the
text to go afterwards.  Finally, if PAD is non-nil, the titles are all
indented to the same column, which is eleven plus the length of
PRE-TITLE.  Otherwise just one space is placed between the number and
the title."
  (interactive (list (read-buffer "Remove folds from buffer: "
                                  (buffer-name)
                                  t)
                     (read-string "String to go before enumerated titles: ")
                     (read-string "String to go after enumerated titles: ")
                     (y-or-n-p "Pad section numbers with spaces? ")))
  (set-buffer (setq buffer (get-buffer buffer)))
  (setq pre-title (or pre-title "")
        post-title (or post-title ""))
  (or folding-mode
      (error "Must be in Folding mode before removing folds"))
  (let* ((new-buffer (get-buffer-create (concat "*Unfolded: "
						(buffer-name buffer)
						"*")))
	 (section-list '(1))
	 (section-prefix-list '(""))

	 (secondary-mark-length (length folding-secondary-top-mark))

	 (secondary-mark folding-secondary-top-mark)
	 (mode major-mode)

	 ;;  [jari] Aug 14 1997
	 ;;  Regexp doesn't allow "footer text" like, so we add one more
	 ;;  regexp to loosen the end criteria
	 ;;
	 ;;  {{{ Subsubsection 1
	 ;;  }}} Subsubsection 1
	 ;;
	 ;;  was:  (regexp folding-regexp)
	 ;;
	 (regexp
	  (concat "\\(^\\|\r\\)\\([ \t]*\\)\\(\\("
		  (regexp-quote folding-top-mark)
		  "\\)\\|\\("
		  (regexp-quote folding-bottom-mark)
		  "[ \t]*.*\\(\\)\\($\\|\r\\)\\)\\)"
		  ))

	 title
	 prefix
	 )

    ;;  was obsolete function: (buffer-flush-undo new-buffer)
    (buffer-disable-undo new-buffer)

    (save-excursion
      (set-buffer new-buffer)
      (delete-region (point-min)
                     (point-max)))
    (save-restriction
      (widen)
      (copy-to-buffer new-buffer (point-min) (point-max)))
    (display-buffer new-buffer t)
    (set-buffer new-buffer)
    (subst-char-in-region (point-min) (point-max) ?\r ?\n)
    (funcall mode)

    (while (re-search-forward regexp nil t)
      (if (match-beginning 4)
          (progn
            (goto-char (match-end 4))

	    ;;  - Move after start fold and read thetitle from there
	    ;;  - Then move back and kill the fold mark
	    ;;
            (setq title
                  (buffer-substring (point)
                                    (progn (end-of-line)
                                           (point))))
            (delete-region (save-excursion
                             (goto-char (match-beginning 4))
                             (skip-chars-backward "\n\r")
                             (point))
                           (progn
                             (skip-chars-forward "\n\r")
                             (point)))

            (and (<= secondary-mark-length
                     (length title))
                 (string-equal secondary-mark
                               (substring title
                                          (- secondary-mark-length)))
                 (setq title (substring title
                                        0
                                        (- secondary-mark-length))))
            (setq section-prefix-list
                  (cons (setq prefix (concat (car section-prefix-list)
                                             (int-to-string (car section-list))
                                             "."))
                        section-prefix-list))

            (or (cdr section-list)
                (insert ?\n))
            (setq section-list (cons 1
				     (cons (1+ (car section-list))
					   (cdr section-list))))


            (setq title (concat prefix
                                (if pad
                                    (make-string
                                     (max 2 (- 8 (length prefix))) ? )
                                  " ")
                                title))
            (message "Reformatting: %s%s%s"
                     pre-title
                     title
                     post-title)
            (insert "\n\n"
                    pre-title
                    title
                    post-title
                    "\n\n"))
        (goto-char (match-beginning 5))

        (or (setq section-list (cdr section-list))
            (error "Too many bottom-of-fold marks"))

        (setq section-prefix-list (cdr section-prefix-list))
        (delete-region (point)
                       (progn
                         (forward-line 1)
                         (point)))
	))

    (and (cdr section-list)
         (error
          "Too many top-of-fold marks -- reached end of file prematurely"))
    (goto-char (point-min))
    (buffer-enable-undo)
    (set-buffer-modified-p nil)
    (message "All folds reformatted.")))

;;}}}
;;}}}

;;{{{ code: Standard fold marks for various major modes

;;{{{ A function to set default marks, `folding-add-to-marks-list'

(defun folding-add-to-marks-list (mode top bottom
                                    &optional secondary noforce message)
  "Add/set fold mark list for a particular major mode.
When called interactively, asks for a `major-mode' name, and for
fold marks to be used in that mode.  It adds the new set to
`folding-mode-marks-alist', and if the mode name is the same as the current
major mode for the current buffer, the marks in use are also changed.

If called non-interactively, arguments are MODE, TOP, BOTTOM and
SECONDARY.  MODE is the symbol for the major mode for which marks are
being set.  TOP, BOTTOM and SECONDARY are strings, the three fold marks
to be used.  SECONDARY may be nil (as opposed to the empty string), but
the other two must be non-empty strings, and is an optional argument.

Two other optional arguments are NOFORCE, meaning do not change the
marks if marks are already set for the specified mode if non-nil, and
MESSAGE, which causes a message to be displayed if it is non-nil.  This
is also the message displayed if the function is called interactively.

To set default fold marks for a particular mode, put something like the
following in your .emacs:

\(folding-add-to-marks-list 'major-mode \"(** {{{ \" \"(** }}} **)\" \" **)\")

Look at the variable `folding-mode-marks-alist' to see what default settings
already apply.

`folding-set-marks' can be used to set the fold marks in use in the current
buffer without affecting the default value for a particular mode."
  (interactive
   (let* ((mode (completing-read
                 (concat "Add fold marks for major mode ("
                         (symbol-name major-mode)
                         "): ")
                 obarray
                 (function
                  (lambda (arg)
                    (and (commandp arg)
                         (string-match "-mode\\'"
                                       (symbol-name arg)))))
                 t))
          (mode (if (equal mode "")
                    major-mode
                  (intern mode)))
          (object (assq mode folding-mode-marks-alist))
          (old-top (and object
                   (nth 1 object)))
          top
          (old-bottom (and object
                      (nth 2 object)))
          bottom
          (secondary (and object
                         (nth 3 object)))
          (prompt "Top fold marker: "))
     (and (equal secondary "")
          (setq secondary nil))
     (while (not top)
       (setq top (read-string prompt (or old-top "{{{ ")))
       (and (equal top "")
            (setq top nil)))
     (setq prompt (concat prompt
                          top
                          ", Bottom marker: "))
     (while (not bottom)
       (setq bottom (read-string prompt (or old-bottom "}}}")))
       (and (equal bottom "")
            (setq bottom nil)))
     (setq prompt (concat prompt
                          bottom
                          (if secondary
                              ", Secondary marker: "
                            ", Secondary marker (none): "))
           secondary (read-string prompt secondary))
     (and (equal secondary "")
          (setq secondary nil))
     (list mode top bottom secondary nil t)))
  (let ((object (assq mode folding-mode-marks-alist)))
    (if (and object
             noforce
             message)
        (message "Fold markers for `%s' are already set."
                 (symbol-name mode))
      (if object
          (or noforce
              (setcdr object (if secondary
                                 (list top bottom secondary)
                               (list top bottom))))
        (setq folding-mode-marks-alist
              (cons (if secondary
                        (list mode top bottom secondary)
                      (list mode top bottom))
                    folding-mode-marks-alist)))
      (and message
             (message "Set fold marks for `%s' to \"%s\" and \"%s\"."
                      (symbol-name mode)
                      (if secondary
                          (concat top "name" secondary)
                        (concat top "name"))
                      bottom)
             (and (eq major-mode mode)
                  (folding-set-marks top bottom secondary))))))

;;}}}
;;{{{ Set some useful default fold marks

(folding-add-to-marks-list 'Bison-mode		"/* {{{ " "/* }}} */" " */" t)
(folding-add-to-marks-list 'LaTeX-mode		"%{{{ "	  "%}}}" nil t)
(folding-add-to-marks-list 'TeX-mode		"%{{{ "	  "%}}}" nil t)
(folding-add-to-marks-list 'bison-mode             "/* {{{ " "/* }}} */" " */" t)
(folding-add-to-marks-list 'c++-mode               "// {{{ " "// }}}" nil t)
(folding-add-to-marks-list 'c-mode                 "/* {{{ " "/* }}} */" " */" t)
(folding-add-to-marks-list 'emacs-lisp-mode        ";;{{{ "  ";;}}}" nil t)
(folding-add-to-marks-list 'erlang-mode            "%%{{{ "  "%%}}}" nil t)
(folding-add-to-marks-list 'generic-mode		";# "	  ";\$" nil t)
(folding-add-to-marks-list 'gofer-mode             "-- {{{ " "-- }}}" nil t)
(folding-add-to-marks-list 'html-mode	"<!-- [[[ " "<!-- ]]] -->" " -->" t)
(folding-add-to-marks-list 'indented-text-mode     "{{{ "    "}}}" nil t)
(folding-add-to-marks-list 'java-mode              "// {{{ " "// }}}" nil t)
(folding-add-to-marks-list 'latex-mode             "%{{{ "   "%}}}" nil t)
(folding-add-to-marks-list 'lisp-interaction-mode  ";;{{{ "  ";;}}}" nil t)
(folding-add-to-marks-list 'lisp-mode              ";;{{{ "  ";;}}}" nil t)
(folding-add-to-marks-list 'matlab-mode            "%%%{{{ " "%%%}}}" nil t)
(folding-add-to-marks-list 'ml-mode                "(* {{{ " "(* }}} *)" " *)" t)
(folding-add-to-marks-list 'modula-2-mode          "(* {{{ " "(* }}} *)" " *)" t)
(folding-add-to-marks-list 'occam-mode             "-- {{{ " "-- }}}" nil t)
(folding-add-to-marks-list 'orwell-mode            "{{{ "    "}}}" nil t)
(folding-add-to-marks-list 'perl-mode              "# {{{ "  "# }}}" nil t)
;;(folding-add-to-marks-list 'perl-mode              "{ "  "}" nil t)

(folding-add-to-marks-list 'plain-TeX-mode         "%{{{ "   "%}}}" nil t)
(folding-add-to-marks-list 'plain-tex-mode         "%{{{ "   "%}}}" nil t)
(folding-add-to-marks-list 'rexx-mode              "/* {{{ " "/* }}} */" " */" t)
(folding-add-to-marks-list 'sh-script-mode         "# {{{ "  "# }}}" nil t)
(folding-add-to-marks-list 'shellscript-mode       "# {{{ "  "# }}}" nil t)
(folding-add-to-marks-list 'sml-mode               "(* {{{ " "(* }}} *)" " *)" t)
(folding-add-to-marks-list 'tcl-mode               "#{{{ "   "#}}}" nil t)
(folding-add-to-marks-list 'tex-mode               "%{{{ "   "%}}}" nil t)
(folding-add-to-marks-list 'texinfo-mode   "@c {{{ " "@c {{{endfold}}}" " }}}" t)
(folding-add-to-marks-list 'text-mode              "{{{ "    "}}}" nil t)
(folding-add-to-marks-list 'xerl-mode              "%%{{{ "  "%%}}}" nil t)


;; heavy shell-perl-awk programmer in fundamental-mode need # prefix...

(folding-add-to-marks-list 'fundamental-mode       "# {{{ " "# }}}" nil t)

;;}}}

;;}}}

;;{{{ code: Gross, crufty hacks that seem necessary

;; ----------------------------------------------------------------------
;; The functions here have been tested with Emacs 18.55, Emacs 18.58,
;; Epoch 4.0p2 (based on Emacs 18.58) and XEmacs 19.6.

;; Note that XEmacs 19.6 can't do selective-display, and its
;; "invisible extents" don't work either, so Folding mode just won't
;; work with that version.

;; They shouldn't do the wrong thing with later versions of Emacs, but
;; they might not have the special effects either.  They may appear to
;; be excessive; that is not the case.  All of the peculiar things these
;; functions do is done to avoid some side-effect of Emacs' internal
;; logic that I have met.  Some of them work around bugs or unfortunate
;; (lack of) features in Emacs.  In most cases, it would be better to
;; move this into the Emacs C code.

;; Folding mode is designed to be simple to cooperate with as many
;; things as possible.  These functions go against that principle at the
;; coding level, but make life for the user bearable.

;;{{{ folding-subst-regions

;; Substitute newlines for carriage returns or vice versa.
;; Avoid excessive file locking.

;; Substitutes characters in the buffer, even in a read-only buffer.
;; Takes LIST, a list of regions specified as sequence in the form
;; (START1 END1 START2 END2 ...).  In every region specified by each
;; pair, substitutes each occurence of character FIND by REPLACE.

;; The buffer-modified flag is not affected, undo information is not
;; kept for the change, and the function works on read-only files.  This
;; function is much more efficient called with a long sequence than
;; called for each region in the sequence.

;; If the buffer is not modified when the function is called, the
;; modified-flag is set before performing all the substitutions, and
;; locking is temporarily disabled.  This prevents Emacs from trying to
;; make then delete a lock file for *every* substitution, which slows
;; folding considerably, especially on a slow networked filesystem.
;; Without this, on my system, folding files on startup (and reading
;; other peoples' folded files) takes about five times longer.  Emacs
;; still locks the file once for this call under those circumstances; I
;; can't think of a way around that, but it isn't really a problem.

;; I consider these problems to be a bug in `subst-char-in-region'.

(defun folding-subst-regions (list find replace)
  (let ((buffer-read-only   buffer-read-only) ;; Protect read-only flag.
	(modified	    (buffer-modified-p))
	(font-lock-mode	    nil)
	(lazy-lock-mode	    nil)
	(overlay-p	    (folding-use-overlays-p))
        (ask1 (symbol-function 'ask-user-about-supersession-threat))
        (ask2 (symbol-function 'ask-user-about-lock))
	)
    (unwind-protect
        (progn
          (setq buffer-read-only nil)
          (or modified
              (progn
                (fset 'ask-user-about-supersession-threat
                      '(lambda (&rest x) nil))
                (fset 'ask-user-about-lock
                      '(lambda (&rest x) nil))
                (set-buffer-modified-p t))) ; Prevent file locking in the loop
          (while list
            (if overlay-p
                (folding-flag-region (car list) (nth 1 list) (eq find ?\n))
              (subst-char-in-region (car list) (nth 1 list) find replace t))
            (setq list (cdr (cdr list)))))
      ;; buffer-read-only is restored by the let.
      ;; Don't want to change MODIFF time if it was modified before.
      (or modified
          (unwind-protect
              (set-buffer-modified-p nil)
            (fset 'ask-user-about-supersession-threat ask1)
            (fset 'ask-user-about-lock ask2))))))

;;}}}
;;{{{ folding-narrow-to-region

;; Narrow to region, without surprising displays.

;; Similar to `narrow-to-region', but also adjusts window-start to be
;; the start of the narrowed region.  If an optional argument CENTRE is
;; non-nil, the window-start is positioned to leave the point at the
;; centre of the window, like `recenter'.  START may be nil, in which
;; case the function acts more like `widen'.

;; Actually, all the window-starts for every window displaying the
;; buffer, as well as the last_window_start for the buffer are set.  The
;; points in every window are set to the point in the current buffer.
;; All this logic is necessary to prevent the display getting really
;; weird occasionally, even if there is only one window.  Try making
;; this function like normal `narrow-to-region' with a touch of
;; `recenter', then moving around lots of folds in a buffer displayed in
;; several windows.  You'll see what I mean.

;; last_window_start is set by making sure that the selected window is
;; displaying the current buffer, then setting the window-start, then
;; making the selected window display another buffer (which sets
;; last_window_start), then setting the selected window to redisplay the
;; buffer it displayed originally.

;; Note that whenever window-start is set, the point cannot be moved
;; outside the displayed area until after a proper redisplay.  If this
;; is possible, centre the display on the point.

;; In Emacs 19; Epoch or XEmacs, searches all screens for all
;; windows.  In Emacs 19, they are called "frames".

(defun folding-narrow-to-region (&optional start end centre)
  (let* ((the-window	    (selected-window))
	 (selected-buffer   (window-buffer the-window))
	 (window-ring	    the-window)
	 (window	    the-window)
	 (point		    (point))
	 (buffer	    (current-buffer))
         temp
	 )
    (unwind-protect
        (progn
          (unwind-protect
              (progn
                (if (folding-use-overlays-p)
                    (if start
                        (folding-narrow-aux  start end t)
                      (folding-narrow-aux  nil nil nil))
                  (if start
                      (narrow-to-region start end)
                    (widen))
                  )

                (setq point (point))
                (set-window-buffer window buffer)

                (while (progn
                         (and (eq buffer (window-buffer window))
                              (if centre
                                  (progn
                                    (select-window window)
                                    (goto-char point)
                                    (vertical-motion
                                     (- (lsh (window-height window) -1)))
                                    (set-window-start window (point))
                                    (set-window-point window point))
                                (set-window-start window (or start 1))
                                (set-window-point window point)))

                         (not (eq (setq window (next-window window nil t))
				  window-ring))
			 )) ;; while-progn

		) ;; progn overlays
            nil ;; epoch screen
            (select-window the-window)
	    ) ;; unwind-protect INNER

          ;; Set last_window_start.
          (unwind-protect
              (if (not (eq buffer selected-buffer))
                  (set-window-buffer the-window selected-buffer)
                (if (get-buffer "*scratch*")
                    (set-window-buffer the-window (get-buffer "*scratch*"))
                  (set-window-buffer
                   the-window (setq temp (generate-new-buffer " *temp*"))))
                (set-window-buffer the-window buffer))
            (and temp
                 (kill-buffer temp))))
      ;; Undo this side-effect of set-window-buffer.
      (set-buffer buffer)
      (goto-char (point)))))

;;}}}

;;}}}

;;{{{ code: folding-end-mode-quickly

(defun folding-end-mode-quickly ()
  "Replace all ^M's with linefeeds and widen a folded buffer.
Only has any effect if Folding mode is active.

This should not in general be used for anything.  It is used when changing
major modes, by being placed in kill-mode-tidy-alist, to tidy the buffer
slightly.  It is similar to `(folding-mode 0)', except that it does not
restore saved keymaps etc.  Repeat: Do not use this function.  Its
behaviour is liable to change."
  (and (boundp 'folding-mode)
       (assq 'folding-mode
             (buffer-local-variables))
       folding-mode
       (progn
         (if (folding-use-overlays-p)
             (folding-narrow-to-region nil nil)
           (widen))
         (folding-clear-stack)
         (folding-subst-regions (list 1 (point-max)) ?\r ?\n))))

;;{{{ eval-current-buffer-open-folds

(defun eval-current-buffer-open-folds (&optional printflag)
  "Evaluate all of a folded buffer as Lisp code.
Unlike `eval-current-buffer', this function will evaluate all of a
buffer, even if it is folded.  It will also work correctly on non-folded
buffers, so is a good candidate for being bound to a key if you program
in Emacs-Lisp.

It works by making a copy of the current buffer in another buffer,
unfolding it and evaluating it.  It then deletes the copy.

Programs can pass argument PRINTFLAG which controls printing of output:
nil means discard it; anything else is stream for print."
  (interactive)
  (if (or (and (boundp 'folding-mode)
               folding-mode))
      (let ((temp-buffer
             (generate-new-buffer (buffer-name))))
        (message "Evaluating unfolded buffer...")
        (save-restriction
          (widen)
          (copy-to-buffer temp-buffer 1 (point-max)))
        (set-buffer temp-buffer)
        (subst-char-in-region 1 (point-max) ?\r ?\n)
        (let ((real-message-def (symbol-function 'message))
              (suppress-eval-message))
          (fset 'message
                (function
                 (lambda (&rest args)
                   (setq suppress-eval-message t)
                   (fset 'message real-message-def)
                   (apply 'message args))))
          (unwind-protect
              (eval-current-buffer printflag)
            (fset 'message real-message-def)
            (kill-buffer temp-buffer))
          (or suppress-eval-message
              (message "Evaluating unfolded buffer... Done"))))
    (eval-current-buffer printflag)))

;;}}}

;;}}}

;;{{{ code: ISearch support, walks in and out of folds

;; This used to be a package of it's own.
;; Requires Emacs 19 or XEmacs.  Does not work under Emacs 18.

;;{{{ Variables

(defcustom folding-isearch-install t
  "*When non-nil, the isearch commands will handle folds."
  :type 'boolean  :group 'folding)

(defvar folding-isearch-stack nil
  "Temporary storage for `folding-stack' during isearch.")

;; Lists of isearch commands to replace

;; These do normal searching.

(defvar folding-isearch-normal-cmds
  '(isearch-repeat-forward
    isearch-repeat-backward
    isearch-toggle-regexp
    isearch-toggle-case-fold
    isearch-delete-char
    isearch-abort
    isearch-quote-char
    isearch-other-control-char
    isearch-other-meta-char
    isearch-return-char
    isearch-exit
    isearch-printing-char
    isearch-whitespace-chars
    isearch-yank-word
    isearch-yank-line
    isearch-yank-kill
    isearch-*-char
    isearch-\|-char
    isearch-mode-help
    isearch-yank-x-selection
    isearch-yank-x-clipboard
    )
  "List if isearch commands doing normal search.")


;; Enables the user to edit the search string

;; Missing, present in XEmacs isearch-mode.el. Not necessary?
;; isearch-ring-advance-edit, isearch-ring-retreat-edit, isearch-complete-edit
;; isearch-nonincremental-exit-minibuffer, isearch-yank-x-selection,
;; isearch-yank-x-clipboard

(defvar folding-isearch-edit-enter-cmds
  '(isearch-edit-string
    isearch-ring-advance
    isearch-ring-retreat
    isearch-complete)                   ; (Could also stay in search mode!)
  "List of isearch commands which enters search string edit.")


;; Continues searching after editing.

(defvar folding-isearch-edit-exit-cmds
  '(isearch-forward-exit-minibuffer     ; Exits edit
    isearch-reverse-exit-minibuffer
    isearch-nonincremental-exit-minibuffer)
  "List of isearch commands which exits search string edit.")

;;}}}
;;{{{ Keymaps (an Isearch hook)

(defvar folding-isearch-mode-map nil
  "Modified copy of the isearch keymap.")


;; Create local coipes of the keymaps. The `isearch-mode-map' is
;; copied to `folding-isearch-mode-map' while `minibuffer-local-isearch-map'
;; is made local. (Its name is used explicitly.)
;;
;; Note: This is called every time the search is started.

(defun folding-isearch-hook-function ()
  "Update the isearch keymaps for usage with folding mode."
  (if (and (boundp 'folding-mode) folding-mode)
      (let ((cmds (append folding-isearch-normal-cmds
                          folding-isearch-edit-enter-cmds
                          folding-isearch-edit-exit-cmds))
	    )

        (setq folding-isearch-mode-map (copy-keymap isearch-mode-map))
        (make-local-variable 'minibuffer-local-isearch-map)

        ;; Make sure the descructive operations below doesn't alter
        ;; the global instance of the map.

        (setq minibuffer-local-isearch-map
              (copy-keymap minibuffer-local-isearch-map))

        (setq folding-isearch-stack folding-stack)

        (while cmds
          (substitute-key-definition
           (car cmds)
           (intern (concat "folding-" (symbol-name (car cmds))))
           folding-isearch-mode-map)
          (substitute-key-definition
           (car cmds)
           (intern (concat "folding-" (symbol-name (car cmds))))
           minibuffer-local-isearch-map)
          (setq cmds (cdr cmds)))

        ;; Install our keymap

        (cond
	 (folding-xemacs-p
	  (let ((f 'set-keymap-name))
	    (funcall f folding-isearch-mode-map 'folding-isearch-mode-map))
	  (setq minor-mode-map-alist
		(cons (cons 'isearch-mode folding-isearch-mode-map)
		      (delq (assoc 'isearch-mode minor-mode-map-alist)
			    minor-mode-map-alist))))

	 ((boundp 'overriding-terminal-local-map)
	  (funcall (symbol-function 'set)
		   'overriding-terminal-local-map folding-isearch-mode-map))

	 ((boundp 'overriding-local-map)
	  (setq overriding-local-map folding-isearch-mode-map)
	  ))

	)))


;; Undoes the `folding-isearch-hook-function' function.

(defun folding-isearch-end-hook-function ()
  "Actions to perform at the end of isearch in folding mode."
  (when (and (boundp 'folding-mode) folding-mode)
    (kill-local-variable 'minibuffer-local-isearch-map)
    (setq folding-stack folding-isearch-stack)))


(when folding-isearch-install
  (add-hook 'isearch-mode-hook 'folding-isearch-hook-function)
  (add-hook 'isearch-mode-end-hook 'folding-isearch-end-hook-function))

;;}}}
;;{{{ Normal search routines

;; Generate the replacement functions of the form:
;;    (defun folding-isearch-repeat-forward ()
;;      (interactive)
;;      (folding-isearch-general 'isearch-repeat-forward))

(let ((cmds folding-isearch-normal-cmds))
  (while cmds
    (eval
     (` (defun (, (intern (concat "folding-" (symbol-name (car cmds))))) ()
          "Automatically generated"
          (interactive)
          (folding-isearch-general (quote (, (car cmds)))))))
    (setq cmds (cdr cmds))))


;; The HEART! Executes command and updates the foldings.
;; This is capable of detecting a `quit'.

(defun folding-isearch-general (function)
  "Execute isearch command FUNCTION and adjusts the folding."
  (let* ((quit-isearch  nil)
         (area-beg      (point-min))
         (area-end      (point-max))
         pos
         )
    (cond
     ((memq function '(isearch-abort isearch-quit))
      (setq quit-isearch t))

     (t
      (save-restriction
        (widen)
        (condition-case nil
            (funcall function)
          (quit  (setq quit-isearch t)))
        (setq pos (point)))

      ;; Situation
      ;; o   user has folded buffer
      ;; o   He manually narrows, say to function !
      ;; --> there is no fold marks at the beg/end --> this is not a fold

      (condition-case nil
          ;; "current mode has no fold marks..."
          (folding-region-has-folding-marks-p area-beg area-end)
        (error (setq quit-isearch t)))

      (if (and (null quit-isearch))
          (folding-goto-char pos))
      ))

    (if quit-isearch
        (signal 'quit nil))
    ))

;;}}}
;;{{{ Edit search string support

(defvar folding-isearch-current-buffer nil
  "The buffer we are editing, so we can widen it when in minibuffer.")


;;
;; Functions which enters edit mode.
;;

(defun folding-isearch-edit-string ()
  "Replace `isearch-edit-string' when in `folding-mode'."
  (interactive)
  (folding-isearch-start-edit 'isearch-edit-string))

(defun folding-isearch-ring-advance ()
  "Replace `isearch-ring-advance' when in `folding-mode'."
  (interactive)
  (folding-isearch-start-edit 'isearch-ring-advance))

(defun folding-isearch-ring-retreat ()
  "Replace `isearch-ring-retreat' when in `folding-mode'."
  (interactive)
  (folding-isearch-start-edit 'isearch-ring-retreat))

(defun folding-isearch-complete ()
  "Replace `isearch-complete' when in `folding-mode'."
  (interactive)
  (folding-isearch-start-edit 'isearch-complete))


;; Start and wait for editing. When (funcall fnk) returns
;; we are back in interactive search mode.
;;
;; Store match data!

(defun folding-isearch-start-edit (fnk)
  (let (pos)
    (setq folding-isearch-current-buffer (current-buffer))
    (save-restriction
      (funcall fnk)
      ;; Here, we are widend, by folding-isearch-*-exit-minibuffer.
      (setq pos (point)))
    (folding-goto-char pos)))

;;
;; Functions which exits edit mode.
;;

;; The `widen' below will be caught by the `save-restriction' above, thus
;; this will not cripple `folding-stack'.

(defun folding-isearch-forward-exit-minibuffer ()
  "Replace `isearch-forward-exit-minibuffer' when in `folding-mode'."
  (interactive)
  ;; Make sure we can continue searching outside narrowing.
  (save-excursion
    (set-buffer folding-isearch-current-buffer)
    (widen))
  (isearch-forward-exit-minibuffer))

(defun folding-isearch-reverse-exit-minibuffer ()
  "Replace `isearch-reverse-exit-minibuffer' when in `folding-mode'."
  (interactive)
  ;; Make sure we can continue searching outside narrowing.
  (save-excursion
    (set-buffer folding-isearch-current-buffer)
    (widen))
  (isearch-reverse-exit-minibuffer))

(defun folding-isearch-nonincremental-exit-minibuffer ()
  "Replace `isearch-reverse-exit-minibuffer' when in `folding-mode'."
  (interactive)
  ;; Make sure we can continue searching outside narrowing.
  (save-excursion
    (set-buffer folding-isearch-current-buffer)
    (widen))
  (isearch-nonincremental-exit-minibuffer))

;;}}}
;;{{{ Special XEmacs support

;; In XEmacs, all isearch commands must have the property `isearch-command'.

(if folding-xemacs-p
    (let ((cmds (append folding-isearch-normal-cmds
                        folding-isearch-edit-enter-cmds
                        folding-isearch-edit-exit-cmds)))
      (while cmds
        (put (intern (concat "folding-" (symbol-name (car cmds))))
             'isearch-command t)
        (setq cmds (cdr cmds)))))

;;}}}
;;{{{ General purpuse function.

;;; ----------------------------------------------------------------------
;;;
(defun folding-goto-char (pos)
  "Goto character POS, changing fold if necessary."
  ;; Make sure POS is inside the visible area of the buffer.
  (goto-char pos)
  (if (eq pos (point))                  ; Point inside narrowed area?
      nil
    (folding-show-all)                    ; Fold everything and goto top.
    (goto-char pos))
  ;; Enter if point is folded.
  (if (folding-point-folded-p pos)
      (progn
        (folding-shift-in)                    ; folding-shift-in can change the pos.
        (setq folding-isearch-stack folding-stack)
        (setq folding-stack '(folded))
        (goto-char pos))))


;;; ----------------------------------------------------------------------
;;;
(defun folding-point-folded-p (pos)
  "Non-nil when POS is not visible."
  (if (folding-use-overlays-p)
      (let ((overlays (overlays-at (point)))
            (found nil))
        (while (and (not found) (overlayp (car overlays)))
          (setq found (overlay-get (car overlays) 'fold)
                overlays (cdr overlays)))
        found)
    (save-excursion
      (goto-char pos)
      (beginning-of-line)
      (skip-chars-forward "^\r" pos)
      (not (eq pos (point))))
    ))




;;}}}

;;}}}
;;{{{ code: Additional functions


(defvar folding-comment-folding-table
  '((c-mode folding-comment-c-mode folding-uncomment-c-mode)
    )
  "Table of functions to comment and uncomment folds.
Function is called with two arguments:

  number    start of fold mark
  marker    end of fold mark

Function must return:

  (beg . end)    start of fold, end of fold

Tabe Format:
 '((MAJOR-MODE COMMENT-FUNCTION UNCOMMENT-FUNCTION) ..)")


;;; ----------------------------------------------------------------------
;;;
(defun folding-uncomment-mode-generic (beg end tag)
  "Remove two TAG lines and return (beg . end)"
    (re-search-forward tag (marker-position end))
    (beginning-of-line)
    (kill-line 1)
    (re-search-forward tag (marker-position end))
    (beginning-of-line)
    (kill-line 1)
    (cons beg end))

;;; ----------------------------------------------------------------------
;;;
(defun folding-comment-mode-generic (beg end tag1 &optional tag2)
  "Add two TAG lines and return (beg . end)"
    (insert tag1)
    (goto-char (marker-position end))
    (insert (or tag2 tag1))
    (cons beg end))

;;; ----------------------------------------------------------------------
;;;
(defun folding-uncomment-c-mode  (beg end)
  "Uncomment"
  (folding-uncomment-mode-generic
   beg end (regexp-quote " comment /* FOLDING -COM- */")))

;;; ----------------------------------------------------------------------
;;;
(defun folding-comment-c-mode  (beg end)
  "Comment"
  (let* ((tag " /* FOLDING -COM- */")
         )
    (folding-comment-mode-generic
     beg end
     (concat "#if comment"    tag "\n")
     (concat "#endif comment" tag "\n"))))

;;; ----------------------------------------------------------------------
;;;
(defun folding-comment-fold  (&optional uncomment)
  "Comment or UNCOMMENT all text inside single fold.
If there are subfolds this function won't work as expected.
User must know that there are no subfolds.

The heading has -COM- at the end when the fold is commented.
Point must be over fold heading {{{ when function is called.

Note:

 You can use this function only in modes that do _not_ have
 `comment-end'. Ie. don't use this function in modes like C (/* */), because
 nested comments are not allowed. See this:

    /* {{{ fold */
       code  /* comment of the code */
    /* }}} */

 Fold can't know how to comment the `code' inside fold, because comments
 do not nest.

Implementation detail:

 {{{ FoldHeader-COM-

 If the fold header has -COM- at the end, then the fold is supposed to
 be commented. And if there is no -COM- then fold will be consideres
 as normal fold. Do not loose the or add the -COM- yourself or it will
 confuse the state of the fold.

References:

 `folding-comment-folding-table'"
  (interactive "P")
  (let* ((state	    (folding-mark-look-at 'move))
	 (closed    (eq 0 state))
	 (id	    "-COM-")
	 (opoint    (point))
	 (mode-elt  (assq major-mode folding-comment-folding-table))

	 comment
	 ret
	 beg
	 end
         )

    (unless mode-elt
      (if (stringp (nth 2 (folding-get-mode-marks major-mode)))
	  (error "\
Folding: function usage error, mode with `comment-end' is not supported.")))

    (when (or (null comment-start)
	      (not (string-match "[^ \t\n]" comment-start)))
      (error "Empty comment-start."))

    (unless (memq state '( 0 1 11))
      (error "Incorrect fold state. Point must be over {{{."))


    ;;	There is nothing to do if this fold heading does not have
    ;;	the ID when uncommeting the fold.

    (setq state (looking-at (concat ".*" id)))

    (when (or (and uncomment state)
	      (and (null uncomment) (null state))
	      )
      (when closed (save-excursion (folding-show-current-entry)))

      (folding-pick-move)			;Go to end
      (beginning-of-line)

      (setq end (point-marker))

      (goto-char opoint)		;And off the fold heading
      (forward-line 1)
      (setq beg (point))

      (setq comment (concat comment-start id))

      (cond
       (mode-elt
	(setq ret
	      (if uncomment
		  (funcall (nth 2 mode-elt) (point) end)
		(funcall (nth 1 mode-elt) (point) end)))
	(goto-char (cdr ret)))

       (uncomment
	(while (< (point) (marker-position end))
	  (if (looking-at comment)
	      (delete-region (point) (match-end 0)))
	  (forward-line 1)))

       (t
	(while (< (point) (marker-position end))
	  (if (not (looking-at comment))
	      (insert comment))
	  (forward-line 1))))

      (setq end nil)			;kill marker

      ;;  Remove the possible tag from the fold name line

      (goto-char opoint)

      (setq id (concat (or comment-start "") id (or comment-end "")))

      (if (re-search-forward (regexp-quote id) beg t)
	  (delete-region (match-beginning 0)  (match-end 0)))

      (when (null uncomment)
	(end-of-line)
	(insert id))

      (if closed
	  (folding-hide-current-entry))

      (goto-char opoint)
      )))


;;; ----------------------------------------------------------------------
;;;
(defun folding-convert-to-major-folds ()
  "Convert fold marks according to major-mode fold marks.
This function replaces all fold marks }}} and {{{
with major mode's fold marks.

As a side effecs also corrects all foldings to standard notation.
Eg. following ,where correct folding-beg should be \"#{{{ \"
Note that /// marks foldings.


  ///                  ;wrong fold
  #     ///           ;too many spaces, fold format error
  # ///title            ;ok, but title too close

  produces

  #///
  #///
  #/// title

<<< Remember to 'unfold' whole buffer before using this function >>>
"
  (interactive)
  (let ((bm "{{{")			; begin match mark
	(em "}}}")			;
	el				; element
	b				; begin
	e				; end
	e2				; end2
	pp				;
	)

    (catch 'out				; is folding active/loaded ??

      (unless (setq el (folding-get-mode-marks major-mode))
	(throw 'out t))			; ** no mode found

      ;; ok , we're in busines. Search whole buffer and replace.

      (setq b  (elt el 0)
	    e  (elt el 1)
	    e2 (or (elt el 2) "")
	    )

      (save-excursion
	(goto-char (point-min))		; start from the beginnig of buffer

	(while (re-search-forward (regexp-quote bm) nil t)

	  ;; set the end position for fold marker

	  (setq pp (point))
	  (beginning-of-line)

	  (if (looking-at (regexp-quote b)) ; should be mode-marked; ok, ignore
	      (goto-char pp)		; note that beg-of-l cmd, move rexp
	    (delete-region (point) pp)
	    (insert b)
	    (when (not (string= "" e2))
	      (unless (looking-at (concat ".*" (regexp-quote e2)))
		(end-of-line)
		(insert e2)
		)))			; replace with right fold mark
	  )

	;; handle end marks , identical func compared to prev.

	(goto-char (point-min))

	(while (re-search-forward (regexp-quote em)nil t)
	  (setq pp (point))
	  (beginning-of-line)
	  (if (looking-at (regexp-quote e))
	      (goto-char pp)
	    (delete-region (point) (progn (end-of-line) (point)))
	    (insert e)
	    ))
	) ;; excursion end

      ;; ---------------------------------------- catch 'out
      )))


;;; ----------------------------------------------------------------------
;;;
(defun fold-all-comment-blocks-in-region (beg end)
  "Put all comments in folds inside BEG END.
Notice: Make sure there is no interfering folds inside the area,
because the results may and up corrupted.

This only works for modes that DO NOT have `comment-end'.
The `comment-start' must be left flushed in order to counted in.

Aftert this

    ;; comment
    ;; comment

    code


    ;; comment
    ;; comment

    code

The result will be:


    ;; {{{ 1

    ;; comment
    ;; comment

    ;; }}}

    code

    ;; {{{ 2

    ;; comment
    ;; comment

    ;; }}}

    code"
  (interactive "*r")

  (unless comment-start
    (error "Folding: Mode does not define `comment-start'"))

  (when (and (stringp comment-end)
	     (string-match "[^ \t]" comment-end))
    (error "Folding: Mode defines non-empty `comment-end'."))

  (let* ((count          0)
	 (comment-regexp (concat "^" comment-start))
	 (marker         (point-marker))
	 leading
	 done
         )
    (multiple-value-bind (left right ignore)
	(folding-get-mode-marks)

      ;; %%%{{{  --> "%%%"

      (string-match (concat (regexp-quote comment-start) "+") left)
      (setq leading (match-string 0 left))


      (save-excursion
	(goto-char beg)
	(beginning-of-line)
	(while (re-search-forward comment-regexp nil t)

	  (move-marker marker (point))
	  (setq done nil)
	  (beginning-of-line)
	  (forward-line -1)

	  ;; 2 previous lines Must not contain FOLD beginning already

	  (unless (looking-at (regexp-quote left))
	    (forward-line -1)
	    (unless (looking-at (regexp-quote left))
	      (goto-char (marker-position marker))
	      (beginning-of-line)
	      (insert  left " " (int-to-string count) "\n\n")
	      (incf count)
	      (setq done t)))

	  (goto-char (marker-position marker))

	  (when done

	    ;; Try finding pat of the comment block

	    (if (not (re-search-forward "^[ \t]*$" nil t))
		(goto-char end))
	    (open-line 1)
	    (forward-line 1)
	    (insert right "\n"))

	  )) ;; save-excursion

      ))) ;; function end

;;}}}
;;{{{ Overlay support


;;; ----------------------------------------------------------------------
;;;
(defun folding-use-overlays-p ()
  "Should folding use overlays?."
  (if folding-allow-overlays
      (if folding-xemacs-p
	  ;;  See if we can load overlay.el library that comes in 19.15
	  ;;  This call returns t or nil if load was successfull
	  ;;  Note: is there provide statement? Load is so radical
	  ;;
	  (load "overlay" 'noerr)
        t
        )))

;;; ----------------------------------------------------------------------
;;;
(defun folding-flag-region (from to flag)
  "Hide or show lines from FROM to TO, according to FLAG.
If FLAG is nil then text is shown, while if FLAG is t the text is hidden."
  (let ((inhibit-read-only t)
        overlay
        )
    (save-excursion
      (goto-char from)
      (end-of-line)

      (cond
       (flag
        (setq overlay (make-overlay (point) to))
        (folding-make-overlay-hidden overlay))
       (t
        (if (fboundp 'hs-discard-overlays)
            (hs-discard-overlays (point) to 'invisible t))

        ))
      )))


;;; ----------------------------------------------------------------------
;;;
(defun folding-make-overlay-hidden (overlay)
  ;; Make overlay hidden
  (overlay-put overlay  'fold t)
  ;;  (overlay-put overlay 'intangible t)
  (overlay-put overlay 'invisible t)
  (overlay-put overlay 'owner 'folding)
  )


;;; ----------------------------------------------------------------------
;;;
(defun folding-narrow-aux (start end arg)
  (if (null arg)
    (cond
     (folding-narrow-overlays
      (delete-overlay (car folding-narrow-overlays))
      (delete-overlay (cdr folding-narrow-overlays))
      (setq folding-narrow-overlays nil)
      ))
  (let ((overlay-beg (make-overlay (point-min) start))
        (overlay-end (make-overlay  end (point-max))))
    (overlay-put overlay-beg 'folding-narrow t)
    (overlay-put overlay-beg 'invisible t)
    (overlay-put overlay-beg 'owner 'folding)

    (overlay-put overlay-end 'folding-narrow t)
    (overlay-put overlay-end 'invisible t)
    (overlay-put overlay-end 'owner 'folding)

    (setq folding-narrow-overlays (cons overlay-beg  overlay-end))
    )))

;;}}}

;;{{{ code: end of file tag, provide

;; Local variables:
;; folded-file: t
;; folding-internal-margins: nil
;; end:

(folding-install)

(provide 'folding)
(provide 'folding-isearch)                 ; This used to be a separate package.

(run-hooks 'folding-load-hook)

;;}}}


;;; folding.el ends here
