var e = "ss-widget",
    t = "script",
    a = document,
    r = window;
var s, n, c;
r.SS_WIDGET_TOKEN = "tt-7cfb64";
r.SS_ACCOUNT = "sciencehistory.surveysparrow.com";
r.SS_SURVEY_NAME = "digitial-collections-survey";
if (!a.getElementById(e)) {
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
    n.src = ["https://", "sciencehistory.surveysparrow.com/widget/", r.SS_WIDGET_TOKEN].join("");
    c.parentNode.insertBefore(n, c)
}