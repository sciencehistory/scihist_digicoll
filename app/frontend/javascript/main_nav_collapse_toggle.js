// Some very simple custom JS to duplicate main site collapsed navbar toggle
//
// We have to do some tricks with adding/removing TWO classes with a slightly delay between,
// to get the fade-in/out animation we want to work, with display:block/none too -- we reverse-engineered
// that from the main website source.
document.querySelector(".js-shi-nav-close")?.addEventListener("click", function(e) {
  var header = document.querySelector("#shi-masthead-from-main-website .header");

  if(!header) {
    return;
  }

  header.classList.remove("header_menu-open");
  setTimeout((()=>header.classList.remove("header_menu-prepare")), 300);
});

document.querySelector(".js-header-sandwich-btn")?.addEventListener("click", function(e) {
    var header = document.querySelector("#shi-masthead-from-main-website .header");

    if(!header) {
      return;
    }

    // our own implementation, to get the shi-top-bar-nav to be inside the collapsed menu,
    // we actually copy it to be in a second place in the DOM, leaving it in the first
    // place too, where normally it will be hidden by CSS at small sizes, just in case
    // the screen size changes again. Only if we haven't already done it.
    if (! document.querySelector(".header__nav .shi-top-bar-nav")) {
      var copiedTopBarNav = document.querySelector(".shi-top-bar-nav").cloneNode(true);
      if (copiedTopBarNav) {
        copiedTopBarNav.removeAttribute("id"); // just in case avoid dup id
        document.querySelector(".header__nav")?.appendChild(copiedTopBarNav)
      } else {
        console.log("scihist warning: couldn't find .shi-top-bar-nav to clone it to collapsed menu!");
      }
    }

    document.querySelector("#shi-masthead-from-main-website .header")?.classList.add("header_menu-prepare");
    setTimeout((()=>header.classList.add("header_menu-open")), 0);
});



