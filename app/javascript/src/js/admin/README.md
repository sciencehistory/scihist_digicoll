The files here in app/javascript/src/js/admin are:

* Javascript we only use on the signed-in staff "admin" portion of our website
* managed/compiled via webpacker, of course, as we're in app/javascripts

We put them in a separate subdir just to organize our source -- in the future we MIGHT want to put them in a separate 'pack' delivered only on admin pages, to keep the JS size on public pages down.
