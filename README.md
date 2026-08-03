<!-- PROJECT SHIELDS -->

<div align="center">

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
<br>
[![MELPA](https://melpa.org/packages/bible-gateway-badge.svg)](https://melpa.org/#/bible-gateway)
[![MELPA Stable](https://stable.melpa.org/packages/bible-gateway-badge.svg)](https://stable.melpa.org/#/bible-gateway)
</div>

<!-- PROJECT LOGO -->

<br />
<p align="center">
  <h3 align="center">bible-gateway: A BibleGateway Client for Emacs</h3>  
  <p align="center">
    <b>bible-gateway</b> is a simple Emacs package that fetches the verse of the
	day from https://biblegateway.com, inserts Bible passages at point or in a
	dedicated buffer for reading, opens audio chapters in your browser, and searches for
    keywords displaying the results in Emacs.
    <br />
  </p>
</p>

------

**Features:**
- Fetches the verse of the day for use as an
  [emacs-dashboard](https://github.com/emacs-dashboard/emacs-dashboard) footer
  or `*scratch*` buffer message.
- Inserts a Bible verse, passage, or chapter(s) at point or in a dedicated
  buffer for reading.
- Autocompletes Bible books offering hints about available chapters.
- Supports various public domain Bible translations, including KJV (English),
  LSG (French), RVA (Spanish), ALB (Albanian), UKR (Ukrainian), RUSV (Russian),
  LUTH1545 (German), DNB1930 (Norwegian), BULG (Bulgarian), SV1917 (Swedish),
  DN1933 (Danish), ...
- Plays audio chapters from the [Zondervan King James Audio
  Bible](https://www.biblegateway.com/audio/dramatized/kjv/Gen.1).
- Searches [BibleGateway](https://www.biblegateway.com/) by keyword and displays
  results in a buffer with clickable references and pagination.
- Follows a daily Bible reading plan from a CSV file, opening all of today's
  passages in a single buffer.
- Helps you memorise a Bible verse using a touch-typing practice mode, with live
  color-coded feedback as you type.
- 

------

#### Displaying the Verse of the Day in [emacs-dashboard](https://github.com/emacs-dashboard/emacs-dashboard)

<img src="https://github.com/kristjoc/bible-gateway/blob/main/screenshots/dashboard-dark.png?raw=true">

<img src="https://github.com/kristjoc/bible-gateway/blob/main/screenshots/dashboard-light.png?raw=true">

#### Displaying the Verse of the Day in the `*scratch*` Buffer

<img src="https://github.com/kristjoc/bible-gateway/blob/main/screenshots/scratch-dark.png?raw=true">

#### Inserting a Bible Passage at Point

<img
src="https://github.com/kristjoc/bible-gateway/blob/main/screenshots/bible-gateway-get-passage.gif?raw=true">

#### Playing a Bible Chapter in the Browser

<img
src="https://github.com/kristjoc/bible-gateway/blob/main/screenshots/bible-gateway-listen-passage-in-browser.gif?raw=true">

#### Playing a Bible Chapter with EMMS

Not available anymore due to Copyright.

#### Search for a Keyword in BibleGateway

<img
src="https://github.com/kristjoc/bible-gateway/blob/main/screenshots/bible-gateway-search.gif?raw=true">

#### Memorise Bible verses with touch-typing

<img
src="https://github.com/kristjoc/bible-gateway/blob/main/screenshots/bible-gateway-memorise.gif?raw=true">


------


<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary><h2 style="display: inline-block">Table of Contents</h2></summary>
  <ul>
  <li><a href="#introduction">Introduction</a></li>
  <li><a href="#installation">Installation</a></li>
  <li><a href="#configuration--usage">Configuration & Usage</a></li>
  <li><a href="#contributing">Contributing</a></li>
  <li><a href="#license">License</a></li>
  <li><a href="#contact">Contact</a></li>
  <!---<li><a href="#support">Support</a></li>-->
  <li><a href="#acknowledgements">Acknowledgements</a></li>
  </ul>
</details>


<!-- INTRODUCTION -->
## Introduction

bible-gateway is a simple Emacs package that fetches content from
[BibleGateway](https://www.biblegateway.com/). It can fetch the verse of the
day, insert any Bible verse, passage, or chapter(s) at point or in a dedicated
buffer, play audio chapters in a browser tab, search for keywords, and help you
memorise Bible verses — all from within Emacs.

### Disclaimer

> [!IMPORTANT]
> This package is not affiliated with or endorsed by BibleGateway or any Bible
> copyright holder. It does not include or store any Bible text; all content is
> fetched directly from BibleGateway. It does not store any content except the
> verse of the day, which is cached locally to reduce unnecessary HTTPS
> requests. This is a personal, non-commercial project that tests, supports, and
> encourages the use of public domain translations. If you choose to use a
> copyrighted Bible version, you are solely responsible for ensuring you have
> the proper rights or licenses before using, distributing, or publishing any
> content retrieved through this package.

<!-- INSTALLATION -->
## Installation

### From MELPA (Recommended)

Starting from April 2025,
[`bible-gateway`](https://melpa.org/#/bible-gateway), formerly votd,
is available on MELPA. To install it using the package manager:

1. Ensure MELPA is added to your `package-archives` (if not already):
   ```commonlisp
   (require 'package)
   (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
   ```

2. Refresh the package list and install `bible-gateway`:
   ```commonlisp
   M-x package-refresh-contents RET
   M-x package-install RET bible-gateway RET
   ```

### From GitHub

To fetch the package directly from source you can use
`package-vc-install`, available in Emacs >= 29. Switch to the
`*scratch*` buffer and `yank` the following line:

``` commonlisp
(package-vc-install "https://github.com/kristjoc/bible-gateway")
```

Hit `C-x C-e` once you move the cursor to the last parenthesis. For Emacs 30, you can use the
new `:vc` keyword of `use-package` as follows:

``` commonlisp
(use-package bible-gateway
  :vc "https://github.com/kristjoc/bible-gateway") ; For Emacs>=30
```

Alternatively, clone the repository from GitHub and install `bible-gateway.el` with `M-x package-install-file`.


<!-- CONFIGURATION -->
## Configuration & Usage

### Customizable Variables

`bible-gateway` is customizable via the following `bible-gateway-*`
customization variables:

#### `bible-gateway-bible-version`

**Type:** string  
**Default:** `"KJV"`

The Bible version/translation to use when fetching verses and passages. The following public domain translations are supported:
- `"KJV"` - King James Version (English)
- `"LSG"` - Louis Segond (French)
- `"RVA"` - Reina Valera Antigua (Spanish)
- `"ALB"` - Albanian Bible
- `"UKR"` - Ukrainian Bible
- `"RUSV"` - Russian Synodal Version
- `"LUTH1545"` - Luther Bible 1545 (German)
- `"DNB1930"` - Det Norsk Bibelselskap 1930 (Norwegian)
- `"BULG"` - Bulgarian Bible
- `"SV1917"` - Svenska 1917 (Swedish)
- `"DN1933"` - Dette er Biblen på dansk (Danish)
- 

#### `bible-gateway-text-width`

**Type:** natnum (positive integer)  
**Default:** `80`

The width in characters for formatting the verse of the day text body.

#### `bible-gateway-fallback-verse`

**Type:** string  
**Default:** `"For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."`

The fallback verse text to display when the online request to BibleGateway fails (e.g., due to network issues or geo-blocking).

**Example:**
```commonlisp
(setq bible-gateway-fallback-verse "In the beginning God created the heaven and the earth.")
```

#### `bible-gateway-fallback-reference`

**Type:** string  
**Default:** `"John 3:16"`

The reference citation for the fallback verse.  This should correspond to the verse set in `bible-gateway-fallback-verse`.

**Example:**
```commonlisp
(setq bible-gateway-fallback-reference "Genesis 1:1")
```

#### `bible-gateway-request-timeout`

**Type:** integer  
**Default:** `3`

The timeout in seconds for HTTP requests to BibleGateway. If a request
takes longer than this duration, it will fail and use the fallback
verse.

**Example:**
```commonlisp
(setq bible-gateway-request-timeout 5)  ; Wait up to 5 seconds
```

#### `bible-gateway-include-ref`

**Type:** boolean  
**Default:** `t`

When non-nil, include the reference citation (e.g., "John 3 (KJV)")
when inserting Bible passages with `bible-gateway-get-passage`. Set to
`nil` to insert only the passage text without the reference.

#### `bible-gateway-search-results-per-page`

**Type:** natnum (positive integer)  
**Default:** `100`

Maximum number of search results to fetch per query when using
`bible-gateway-search`.

#### `bible-gateway-use-english-book-names`

**Type:** boolean  
**Default:** `nil`

When non-nil, book name completion always uses **English names** regardless of
the active Bible version set in `bible-gateway-bible-version`. The query sent to
BibleGateway is still made using the correct localized name for the selected
version — the English names are used **only** in the completion UI.

This is useful when working with non-English translations (e.g. `DN1933`,
`SV1917`, `DNB1930`) and you find it easier to type familiar English book names
rather than their localized equivalents. It also ensures that the completion
list is always presented in **canonical Bible order**, unaffected by completion
history or framework-specific sorting.

**Example:**
```commonlisp
;; Always show English book names in completion, even when reading Danish
(setq bible-gateway-bible-version "DN1933")
(setq bible-gateway-use-english-book-names t)
```

With this configuration, typing `Gen` in the completion prompt will
match `Genesis`, but the passage will be fetched as `1 Mosebog` from
BibleGateway.

#### `bible-gateway-plans-dir`

**Type:** directory  
**Default:** `~/.emacs.d/bible-gateway/plans/`

Directory where reading-plan CSV files are stored. Create this directory and
drop your plan CSV(s) inside.

#### `bible-gateway-reading-plan`

**Type:** string or `nil`  
**Default:** `nil`

Filename of the active reading plan (relative to `bible-gateway-plans-dir`). Set
this to enable the `M-x bible-gateway-read-today` command.

**Example:**
```commonlisp
(setq bible-gateway-reading-plan "bibleplan.csv")
```

The CSV must have a header row `"Date","Passage"` followed by ISO-dated rows
(`YYYY-MM-DD`) with one or more semicolon-separated references per day:

```csv
"Date","Passage"
"2026-01-01","Gen 1; Mat 1; Ezr 1; Acts 1"
"2026-01-02","Gen 2; Mat 2; Ezr 2; Acts 2"
```

You can generate one with
[Bible Reading Plan Generator](https://biblereadingplangenerator.com/) or hand-write your
own.

The CSV's book abbreviations are English regardless of the Bible version you
read in. A French user with `(setq bible-gateway-bible-version "LSG")` can use
the same English CSV and the readings will be fetched in French. The CSV
selects *which* passages; `bible-gateway-bible-version` selects *what language*
they're returned in.

#### `bible-gateway-memorise-beep-on-error`

**Type:** boolean
**Default:** `nil`

When non-nil, `bible-gateway-memorise` beeps/flashes every time there is a
mistake anywhere in the text you've typed so far. It keeps signaling on every
keystroke until you go back and fix the error. Off by default for a quieter
experience; enable it if you want a stronger nudge to correct mistakes
immediately rather than typing on.

**Example:**
```commonlisp
(setq bible-gateway-memorise-beep-on-error t)
```


### `*scratch*` buffer message

If you would like to use the verse of the day as your `*scratch*`
buffer message, use the following configuration in your `init.el`:

``` commonlisp
(use-package bible-gateway
  :config
  (setq initial-scratch-message
	(concat ";;; *scratch* ;;;\n\n"
		(string-join
		 (mapcar (lambda (line) (concat ";;; " line))
			 (split-string (bible-gateway-get-verse) "\n"))
		 "\n")
		"\n;;;\n")))
```
By setting `(setq inhibit-splash-screen t)`, the `*scratch*` buffer will be displayed immediately upon starting Emacs, allowing you to see the verse of the day right away.

### `emacs-dashboard` footer

Additionally, here is a minimal `init.el` to add the verse of the day to your `emacs-dashboard` footer:

``` commonlisp
;;; init.el --- minimal init.el for emacs-dashboard & bible-gateway -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;; melpa needed for installing emacs-dashboard
(with-eval-after-load 'package
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t))

;; place any customize-based settings in custom.el.
(setq custom-file "~/.emacs.d/custom.el")

;; emacs-dashboard config
(use-package dashboard
  :ensure t
  :init
  (dashboard-setup-startup-hook)
  :config
  (setq dashboard-center-content t))

;; install bible-gateway from MELPA
(use-package bible-gateway
  :ensure t
  :after dashboard
  :config
  (setq dashboard-footer-messages (list (bible-gateway-get-verse))))

(provide 'init)
;;; init.el ends here
```

### `emacs-dashboard` footer + `*scratch*` buffer message

To use the verse of the day both as a `*scratch*` message and as a footer in the `emacs-dashboard`, change the `use-package` configuration as follows:

``` commonlisp
(use-package bible-gateway
  :ensure t
  :after dashboard
  :config
  (let ((verse (bible-gateway-get-verse)))
    (setq dashboard-footer-messages (list verse))
    (setq initial-scratch-message
	  (concat ";;; *scratch* ;;;\n\n"
		  (string-join
		   (mapcar (lambda (line) (concat ";;; " line))
                           (split-string verse "\n"))
		    "\n")
                   "\n\n"))))
```

### `doom-dashboard`

If you're using `doom-dashboard`, the following snippet from a Reddit
comment should do the trick.  

``` commonlisp
(use-package bible-gateway
  :config
  (defun doom-dashboard-widget-bible-gateway ()
    (insert "\n" (+doom-dashboard--center +doom-dashboard--width (bible-gateway-get-verse))))
  (add-hook! '+doom-dashboard-functions :append #'doom-dashboard-widget-bible-gateway))
```

### Insert a Bible passage at point or in a dedicated buffer

To insert a Bible passage in the current buffer, at point, invoke `M-x
bible-gateway-get-passage`, start typing the Bible book and autocomplete with
`TAB`. Hit `RET` once the book is selected and enter the desired passage. It is
possible to request a single verse (John 3:16), a verse range (John 3:16-17), a
single chapter (John 3), and a chapter range (John 3-4). Hit `RET` in the end to
view the content. Set the user option `bible-gateway-include-ref` to `t` to
include the reference, or to `nil` to exclude it. `M-x
bible-gateway-read-passage` works similarly, but displays the content in a
read-only *Bible Passage* buffer where the current verse is highlighted and you
can navigate with `n/p` or `j/k` to the next/previous verse.  

### Listen to a Bible chapter in your browser

To open the audio link for the selected chapter in your browser from Emacs,
invoke `M-x bible-gateway-listen-passage`, start typing the Bible book and
autocomplete with `TAB`. Hit `RET` once the book is selected and enter the
chapter number. After hitting `RET` again, switch to your browser and click Play
to listen to the chapter. Check out the
[demo](https://github.com/kristjoc/bible-gateway/blob/main/screenshots/bible-gateway-listen-passage-in-browser.gif?raw=true)
above to see how it works. Note that this is
available only for the KJV translation.  

### Listen a Bible chapter in Emacs using EMMS

Due to Copyright, this feature is not available anymore.

Although the mp3 URL is exposed from BibleGateway source website,
downloading them to a temporary directory and playing using EMMS is
not permitted, according to HarperCollins Christian Publishing. The
audio content is protected by copyright law and is intended for
streaming through authorized platforms only. Please, use the Browser
Tab feature for Bible Audio.  

### Search for a keyword in BibleGateway

To search for a keyword in BibleGateway and display the results in Emacs, invoke
`M-x bible-gateway-search` (or open the transient menu with `M-x bible-gateway`
and press `s`, enter the desired keyword, and hit `RET`. The search results will
be displayed in a new Emacs buffer with clickable references and pagination
links at the bottom of the buffer.

Click or press RET on a reference to view the passage in context. Press `n/p` or
`j/k` to navigate between results, `N/P` to navigate between pages, and `q` to close the
buffer. Check out the
[demo](https://github.com/kristjoc/bible-gateway/blob/main/screenshots/bible-gateway-search.gif?raw=true)
above to see how it works.

### Read today's Bible plan

Once `bible-gateway-reading-plan` is set and the CSV is in place, invoke `M-x
bible-gateway-read-today` (or open the transient menu with `M-x bible-gateway`
and press `p`). All of today's passages are fetched and displayed in a single
*Bible Passage* buffer, separated by reference headers. Navigate with `n/p` or
`j/k` between verses as in the regular passage buffer.

If today's date is not present in the CSV (the plan hasn't started yet, or has
already ended), Emacs displays a message and no buffer is opened.  

### Memorise Bible verses with touch-typing

To practice touch-typing while memorising Bible verses, invoke `M-x
bible-gateway-memorise` (or open the transient menu with `M-x bible-gateway` and
press `m`), and select the book and passage as usual. The frame splits into two
buffers: the target verse on top (read-only) and a typing area below where your
cursor starts. As you type, each character is colored green (correct) or red
(incorrect) live in the verse buffer above, so you get immediate feedback on
your accuracy.

The session only completes once every character has been typed correctly — typos
alone won't trigger a "Amen!" message; keep typing/correcting until the whole
passage matches. Once finished, you'll see your typing speed (WPM) and elapsed
time.

Key bindings in the typing buffer:

| Key       | Action                                                                           |
|-----------|----------------------------------------------------------------------------------|
| `C-c C-c` | Finish the session and close both buffers/windows.                               |
| `C-c C-r` | Restart the same verse from scratch.                                             |
| `C-c RET` | Prompt for a new book/passage and start a fresh verse, reusing the same buffers. |

See `bible-gateway-memorise-beep-on-error` below if you'd like an audible/visual
nudge on every mistake.

And that's it! God bless you! Have a great day! :-)


<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community a valuable place
to learn and create. Any contributions you make are **appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/cool`)
3. Commit your Changes (`git commit -m 'Added cool feature'`)
4. Push to the Branch (`git push origin feature/cool`)
5. Open a Pull Request


<!-- LICENSE -->
## License

Distributed under the GPL-3.0 license. See
[`LICENSE`](https://github.com/kristjoc/bible-gateway/blob/main/LICENSE) for more information.


<!-- CONTACT -->
## Contact

[Signal Me](https://signal.me/#eu/7axcnRBeqe3T1fJ3aDXFqFUOU68-DiBzkLbU3U5kogZ1UR7N5YlH665PzEOJSxdD)


<!-- ACKNOWLEDGEMENTS -->
## Acknowledgements

* [All Glory to GOD](https://www.biblegateway.com/passage/?search=John%203%3A16&version=KJV)
* [BibleGateway Ministry](https://www.biblegateway.com/)
* [Emacs Dashboard](https://github.com/emacs-dashboard/emacs-dashboard)
* [gptel: A simple LLM client for Emacs](https://github.com/karthink/gptel)
* [GitHub Copilot](https://github.com/copilot)


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/kristjoc/bible-gateway.svg?style=for-the-badge
[contributors-url]: https://github.com/kristoc/bible-gateway/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/kristjoc/bible-gateway.svg?style=for-the-badge
[forks-url]: https://github.com/kristjoc/bible-gateway/network/members
[stars-shield]: https://img.shields.io/github/stars/kristjoc/bible-gateway.svg?style=for-the-badge
[stars-url]: https://github.com/kristjoc/bible-gateway/stargazers
[issues-shield]: https://img.shields.io/github/issues/kristjoc/bible-gateway.svg?style=for-the-badge
[issues-url]: https://github.com/kristjoc/bible-gateway/issues
