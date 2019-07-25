var scihistDigicoll = scihistDigicoll || {}
$( document ).ready(function() {
    if (jQuery('.accept-cookies-banner-nav').length) {
        scihistDigicoll.setUpAcceptCookiesBanner();
    }
});
scihistDigicoll.setUpAcceptCookiesBanner = function () {
    if (! scihistDigicoll.cookiesAlreadyAcceptedByUser()) {
        setTimeout(function() {
            jQuery('.accept-cookies-banner-nav').fadeIn(500);
        }, 1000);
    }
    jQuery ('.i-accept-link').click(scihistDigicoll.userAcceptsOurCookies);
}
scihistDigicoll.cookiesAlreadyAcceptedByUser = function () {
    return document.cookie.match(/userAcceptsOurCookies=true/) != null;
}
scihistDigicoll.userAcceptsOurCookies = function(event) {
    event.preventDefault();
    var expiratonStr = new Date(new Date()
        .setFullYear(new Date()
        .getFullYear() + 3))
        .toString();
    document.cookie = "userAcceptsOurCookies=true; path=/; expires=" + expiratonStr
    jQuery('.accept-cookies-banner-nav').fadeOut(1000);
}
scihistDigicoll.userDoesNotAcceptOurCookies = function() {
    // This is useful for testing; just call this function
    // from the console and you can test repeatedly.
    document.cookie = "userAcceptsOurCookies=false;"
    jQuery('.accept-cookies-banner-nav').fadeIn(1000);
}