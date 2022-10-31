// Despite our best efforts,
// the survey was not registering
// the fact that users had dismissed it
// or already filled it in; fairly blunt
// attempt to make sure that if
// you don't want to fill in the survey
// or already did fill it in, you
// won't be asked again for a long time.

// Survey PR:
//   https://github.com/sciencehistory/scihist_digicoll/pull/1917
// Survey settings:
//   https://sciencehistory.surveysparrow.com/survey/330435/results/questions
//   https://sciencehistory.surveysparrow.com/survey/330435/channels/2900170/embed/edit


import domready from 'domready';

function userHasStartedSurvey(event) {
  event.preventDefault();
  var expiratonStr = new Date(new Date()
    .setFullYear(new Date()
    .getFullYear() + 3))
    .toString();
  document.cookie = "surveyAlreadyShown=true; path=/; expires=" + expiratonStr;
  // window.console.log("Set the cookie!");
}

function surveyDiv() {
  return document.getElementById("ss_survey_widget");
}

domready( function() {
  if(typeof(surveyDiv()) == 'undefined' || surveyDiv() == null){
    window.console.log("Survey div was not found.");
    return;
  }

  if (surveyAlreadyShown()) {
    window.console.log("You've already clicked on the survey! Not gonna show it.");
  }
  else {
    window.console.log("Launching the survey.");
    sparrowLaunch({
      //add custom params here
    })
  }

  if(surveyDiv().addEventListener) {
    surveyDiv().addEventListener('click', userHasStartedSurvey, true);
  }
});

function surveyAlreadyShown() {
  return document.cookie.match(/surveyAlreadyShown=true/) != null;
}

// This is taken from the survey sparrow site.
function sparrowLaunch(opts){var e="ss-widget",t="script",a=document,r=window,l=localStorage;var s,n,c,rm=a.getElementById('SS_SCRIPT');r.SS_WIDGET_TOKEN="tt-1nbxxaSrT4E1QMjegveHmU";r.SS_ACCOUNT="sciencehistory.surveysparrow.com";r.SS_SURVEY_NAME="digitial-collections-survey";if(!a.getElementById(e) && !l.getItem('removed-ss-widget-tt-1nbxxaSrT4E1QMjegveHmU')){var S=function(){S.update(arguments)};S.args=[];S.update=function(e){S.args.push(e)};r.SparrowLauncher=S;s=a.getElementsByTagName(t);c=s[s.length-1];n=a.createElement(t);n.type="text/javascript";n.async=!0;n.id=e;n.src=["https://","sciencehistory.surveysparrow.com/widget/",r.SS_WIDGET_TOKEN,"?","customParams=",JSON.stringify(opts)].join("");c.parentNode.insertBefore(n,c);r.SS_VARIABLES=opts;rm.parentNode.removeChild(rm);}};


// Useful for testing; just call this function
// from the console and you can test repeatedly.
window.resetSurveyCookie = function() {
  document.cookie = "surveyAlreadyShown=false;  path=/; expires=-1";
}