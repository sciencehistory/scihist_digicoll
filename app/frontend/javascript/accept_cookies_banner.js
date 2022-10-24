$( document ).ready(function() {
    if (jQuery('.accept-cookies-banner-nav').length) {
        setUpAcceptCookiesBanner();
    }
});

function setUpAcceptCookiesBanner() {
    if (! cookiesAlreadyAcceptedByUser()) {
        setTimeout(function() {
            jQuery('.accept-cookies-banner-nav')
                .css("display", "flex")
                .hide()
                .fadeIn(500);
        }, 1000);
    }
    jQuery ('.i-accept-link').click(userAcceptsOurCookies);
}

function cookiesAlreadyAcceptedByUser() {
    return document.cookie.match(/userAcceptsOurCookies=true/) != null;
}

function userAcceptsOurCookies(event) {
    event.preventDefault();
    var expiratonStr = new Date(new Date()
        .setFullYear(new Date()
        .getFullYear() + 3))
        .toString();
    document.cookie = "userAcceptsOurCookies=true; path=/; expires=" + expiratonStr
    jQuery('.accept-cookies-banner-nav').fadeOut(1000);
}

// This is useful for testing; just call this function
// from the console and you can test repeatedly.
window.scihist_userDoesNotAcceptOurCookies = function() {
    document.cookie = "userAcceptsOurCookies=false;"
    jQuery('.accept-cookies-banner-nav').fadeIn(1000);
}
