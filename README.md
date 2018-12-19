# Science History Institute Digital Collections

[![Build Status](https://travis-ci.com/sciencehistory/scihist_digicoll.svg?branch=master)](https://travis-ci.com/sciencehistory/scihist_digicoll)

In progress re-write of our Digital Collections application.

This one is based on the [kithe](https://github.com/sciencehistory/kithe) toolkit, being developed in tandem.

## Development

To set up a development instance on your workstation.

Prequisites:

* ruby installed (I like using chruby and ruby-build to install/manage rubies, some like rvm)
  * `gem install bundler` on new ruby installation
* (MacOS) XCode installed so C dependencies can be compiled
* Postgres installed and running -- on MacOS, I like https://postgresapp.com/
* vips installed --  on MacOS `brew install vips`

```bash
$ git clone git@github.com:sciencehistory/scihist_digicoll.git
$ cd scihist_digicoll
$ bundle install
$ rake db:setup
```

Run app with `./rails server`, it will be available at `http://localhost:3000`.

### Local Env
If you want to change defaults to our config/env variables (managed by `ScihistDigicoll::Env`), you can set them in your shell ENV (via .bash_profile, on the command line, or otherwise), OR you can create a `local_env.yml` or `local_env_development.yml` file. The latter may make sense if you don't want your particular settings to effect the test environment.

For instance, you can switch between whether files are stored in dev-s3 mode, or in the local file system, with:

    STORAGE_MODE=dev_file rails server

Or by putting in a local_env[_development].yml file:

    storage_mode: dev_file

### Running tests

`./bin/rspec`.


