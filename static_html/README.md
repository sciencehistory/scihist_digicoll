The `static_html` directory includes straight static HTML, *not* part of the Rails app. It's being included in the repo for source/version control.

In particular, the [./maintenance_page](./maintenance_page) directory includes static files for a standalone very simple "down for maintanance" page, that we plan to store on S3, and use as heroku custom maintenance page. https://devcenter.heroku.com/articles/maintenance-mode#customizing-your-maintenance-page

The source
