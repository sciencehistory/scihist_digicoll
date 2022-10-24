// A SEPARATE JS entrypoint file with JUST lazysizes. While may load our other JS
// as 'deferred' or at bottom of page, lazysizes recommends loading early.
//
// https://github.com/aFarkas/lazysizes#include-early

import 'lazysizes';
lazySizes.init();
