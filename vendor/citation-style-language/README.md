We use the [citeproc-ruby gem](https://github.com/inukshuk/citeproc-ruby) to format citations as human citations using certain styles.

This uses the Zotero-originated CSL language and styles.  The ruby [csl-styles gem](https://github.com/inukshuk/csl-styles) includes ALL official CSL style and locale files.  It's actually just repackaging from [citation-style-language/styles](https://github.com/citation-style-language/styles) and [citation-style-language/locales/](https://github.com/citation-style-language/locales/) git repositories.

This all works fine, except including ALL the styles is a lot of megabytes.

We actually only use ONE style and ONE locale file, so we copy and paste and vendor them here, at origin from:

https://github.com/citation-style-language/styles/blob/35cad48b70b5df3b5052c4ac15a58f04d8379f6a/chicago-notes-bibliography-16th-edition.csl

https://github.com/citation-style-language/locales/blob/0c7936347495bd54c1fd520e5608edb5c1886d5a/locales-en-US.xml

This saves us a lot of disk space. And we haven't been touching this code for years; at one point we thought we might allow user a choice of styles or locales, but it hasn't really been an area of identified value.

## Choice of Chicago style file/edition

For chicago style, we lock to the older styles for "16th edition", because the newer 17th edition styles, while improved, change things in ways we may have to change some of our code to accomodate,
so for now we'll just lock to style version that we originally developed with -- this hasn't really been an area of code we want to spend much time on, it's good enough.

Fortunately the repo still makes historical Chicago edition styles available.

See: https://github.com/inukshuk/csl-styles/issues/5

