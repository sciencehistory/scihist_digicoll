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
    document.querySelector("#shi-masthead-from-main-website .header")?.classList.add("header_menu-prepare");
    setTimeout((()=>header.classList.add("header_menu-open")), 0);
});



