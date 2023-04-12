// Some very simple custom JS to duplicate main site collapsed navbar toggle
document.querySelector(".js-shi-nav-close")?.addEventListener("click", function(e) {
  document.querySelector("#shi-masthead-from-main-website .header")?.classList.remove("header_menu-open");
});

document.querySelector(".js-header-sandwich-btn")?.addEventListener("click", function(e) {
  document.querySelector("#shi-masthead-from-main-website .header")?.classList.add("header_menu-open");
});



