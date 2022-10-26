// This is a fairly brute-force
// attempt to make sure that if
// you don't want to fill in the survey
// or already did fill it in, you
// won't be asked again for a long time.

// Despite our best efforts,
// the survey was not registering
// the fact that users had dismissed it
// or already filled it in.

// Note that SurveySparrow has its own
// mechanisms in place to attempt to ensure
// that users only fill out the survey once;
// we just don't trust them.
jQuery( document ).ready(function() {
  if (jQuery('#ss_survey_widget').length != 1) {
    return;
  }
  if (surveyAlreadyShown()) {
    window.console.log("You've already clicked on the survey! Not gonna show it.")
  }
  else {
    window.console.log("Launching the survey.")
    sparrowLaunch({
      //add custom params here
    })
  }
  // Any click on the main survey div is
  // interpreted as "user has started survey."
  // Once they start the survey, never show
  // this user the survey again for an entire year.
  jQuery ('#ss_survey_widget').click(userHasStartedSurvey);
});


function surveyAlreadyShown() {
  return document.cookie.match(/surveyAlreadyShown=true/) != null;
}

function userHasStartedSurvey(event) {
  event.preventDefault();
  var expiratonStr = new Date(new Date()
    .setFullYear(new Date()
    .getFullYear() + 3))
    .toString();
  document.cookie = "surveyAlreadyShown=true; path=/; expires=" + expiratonStr;
  window.console.log("Set the cookie!");
}

// This is taken from the survey sparrow site.
function sparrowLaunch(opts) {
  var e = "ss-widget",
    t = "script",
    a = document,
    r = window,
    l = localStorage;
  var s, n, c, rm = a.getElementById('SS_SCRIPT');
  r.SS_WIDGET_TOKEN = "tt-5zUYbALWMcKM1wqSzFDcLi";
  r.SS_ACCOUNT = "sciencehistory.surveysparrow.com";
  r.SS_SURVEY_NAME = "digitial-collections-survey";
  if (!a.getElementById(e) && !l.getItem('removed-ss-widget-tt-5zUYbALWMcKM1wqSzFDcLi')) {
    var S = function() {
      S.update(arguments)
    };
    S.args = [];
    S.update = function(e) {
      S.args.push(e)
    };
    r.SparrowLauncher = S;
    s = a.getElementsByTagName(t);
    c = s[s.length - 1];
    n = a.createElement(t);
    n.type = "text/javascript";
    n.async = !0;
    n.id = e;
    n.src = ["https://", "sciencehistory.surveysparrow.com/widget/", r.SS_WIDGET_TOKEN, "?", "customParams=", JSON.stringify(opts)].join("");
    c.parentNode.insertBefore(n, c);
    r.SS_VARIABLES = opts;
    rm.parentNode.removeChild(rm);
  }
};

// Useful for testing; just call this function
// from the console and you can test repeatedly.
window.resetSurveyCookie = function() {
  document.cookie = "surveyAlreadyShown=false;  path=/; expires=-1";
}