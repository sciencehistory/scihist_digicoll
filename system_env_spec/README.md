# Specs to test command-line environment on host

These specs use rspec, but are in a non-default location separate from our normal application specs.

They test the command-line environment, to ensure that tools we expect to have are present and functional. As we increasingly rely on command-line utilities that our app shells out to, especially for media handling, we need automated tests.

These tests are not run automatically, but are designed to be run manually when you want to ensure the command-line environment is as expected. They can be run on **development** machine or **production (eg) heroku* machine. (We have not yet figured out how to run them on Github Actions CI environment, although surely we can, not sure want to.)

## On development

Just run:

    ./bin/rspec system_env_spec

## On heroku

We have `rspec-rails` gem dependency in default gem group so it is installed in "production" too (ie heroku), to make it possible to simply run:

    heroku run "rspec system_env_spec"

## Note on versions of CLI dependencies

`brew` used on MacOS always installs a recent version. Our heroku ubuntu machines often can't easily get such a recent version. So we may have a lot of version drift between what we have on MacOS development and heroku production.

It's always been this way. It's generally fine.

If the _version_ of a CLI tool is _too high_ (above maximum allowed) for the tests, in either environment, because newer versions have become available -- that may be fine? You may just want to update the test files to allow a higher version.  But we have a maximum allowed to just take note of it, and take extra care that the new higher version still works as we need.

On the other hand, if the version installed is _too low_ (below minimum) it may likely be missing features or bugfixes we depend on, and is more alarming.
