# Science History Institute Digital Collections

[![Build Status](https://travis-ci.com/sciencehistory/scihist_digicoll.svg?branch=master)](https://travis-ci.com/sciencehistory/scihist_digicoll)

In progress re-write of our Digital Collections application.

This one is based on the [kithe](https://github.com/sciencehistory/kithe) toolkit, being developed in tandem.

## Development Setup

To set up a development instance on your workstation.

Prequisites:

* ruby installed (I like using chruby and ruby-build to install/manage rubies, some like rvm)
  * `gem install bundler` on new ruby installation
* (MacOS) XCode installed so C dependencies can be compiled
* Postgres installed and running -- on MacOS, I like https://postgresapp.com/
* `yarn` installed for webpacker -- on MacOS, `brew install yarn`.

```bash
$ git clone git@github.com:sciencehistory/scihist_digicoll.git
$ cd scihist_digicoll
$ bundle install
$ yarn install
$ rake db:setup
```

Run app with `./rails server`, it will be available at `http://localhost:3000`.

### Running tests

`./bin/rspec`.

## Development Notes

### Javascript

We are using webpacker (an ES6-style JS toolchain, supported by Rails 5.1+) for some javascript.
* This is something of an experiment
* We are also still using sprockets for some other javascript at present, in particular for browse-everything integration at present. Bootstrap and JQuery are still included under ordinary javascript, we are endeavoring not to use them in webpacker-controlled JS, but you should be able to use JQuery with `var $ = window.jQuery;`
* We are still using sprockets to control our CSS (scss), **not** webpacker.
* So at the moment our app includes both a sprockets manifest and a webpacker manifest in it's layout, and compiles both in dev and in production assets:precompile. Rails integration should make this just work. We have not at present experimented with running `./bin/webpack-dev-server` separately in dev, we're just letting Rails do it the slower but just-works way.

Some references I found good for understanding webpacker in Rails:
* https://medium.com/@coorasse/goodbye-sprockets-welcome-webpacker-3-0-ff877fb8fa79

