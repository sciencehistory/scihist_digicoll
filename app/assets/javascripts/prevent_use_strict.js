// Blacklight JS has "use strict" as it's first line, which puts our entire
// sprockets manifest into browser JS "strict mode" *if and only if* blacklight
// is the FIRST thing required in the sprocketse manifest!
//
// But that's super confusing and other things in our sprockets may not
// work under strict mode, we don't want to do that.
//
// So we avoid it with this weird hack, by first requiring a JS file that
// doesn't do anything, but can provide a first line that is something
// other than "use strict". PHEW!
//
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Strict_mode

const prevent_use_strict = "prevent_use_strict";
