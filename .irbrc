# This file is meant for configuring irb settings when you are using irb on heroku,
# say via `heroku console`. Since on heroku the unix 'home' directory is application
# root, this ends up being ~/.irbrc on heroku, hooray.

# IRB auto-complete so gets in the way right?
IRB.conf[:USE_AUTOCOMPLETE] = false
