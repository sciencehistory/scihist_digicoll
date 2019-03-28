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
* vips installed --  on MacOS `brew install vips`

```bash
$ git clone git@github.com:sciencehistory/scihist_digicoll.git
$ cd scihist_digicoll
$ bundle install
$ yarn install
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

## Development Notes

### Javascript

We are using webpacker (an ES6-style JS toolchain, supported by Rails 5.1+) for some javascript.
* This is something of an experiment
* We are also still using sprockets for some other javascript at present, in particular for browse-everything integration at present. Bootstrap and JQuery are still included under ordinary javascript, we are endeavoring not to use them in webpacker-controlled JS, but you should be able to use JQuery with `var $ = window.jQuery;`
* We are still using sprockets to control our CSS (scss), **not** webpacker.
* So at the moment our app includes both a sprockets manifest and a webpacker manifest in it's layout, and compiles both in dev and in production assets:precompile. Rails integration should make this just work. We have not at present experimented with running `./bin/webpack-dev-server` separately in dev, we're just letting Rails do it the slower but just-works way.

Some references I found good for understanding webpacker in Rails:
* https://medium.com/@coorasse/goodbye-sprockets-welcome-webpacker-3-0-ff877fb8fa79

## Production deployment

We deploy to AWS, the deployment is done _mostly_ automatically by some ansible playbooks:
* https://bitbucket.org/ChemicalHeritageFoundation/ansible-inventory/src/master/
* https://bitbucket.org/ChemicalHeritageFoundation/ansible-inventory/src/master/create_kithe.yml
* https://bitbucket.org/ChemicalHeritageFoundation/ansible-inventory/src/master/create_kithe_s3.yml

There is some additional manual setup for S3 buckets:
* https://chemheritage.atlassian.net/wiki/spaces/HDCSD/pages/516784129/S3+Bucket+Setup+and+Architecture

## File storage notes

Files are handled by [kithe/shrine](https://github.com/sciencehistory/kithe/blob/master/guides/file_handling.md), and in production stored in S3 buckets. There are a number of different buckets we use for different classes of files in production (which includes staging), documented in the [Atlassian wiki](https://chemheritage.atlassian.net/wiki/spaces/HDCSD/pages/516784129/S3+Bucket+Setup+and+Architecture).

There are different file storage modes available for convenience in development/test. Which can be set with our env key `storage_mode`. In development, you should set env keys `aws_access_key_id` and `aws_secret_access_key` to AWS keys with development access. And then the storage mode will default to `dev_s3` -- which means files of all types are stored in a single bucket, defined by env key `s3_dev_bucket`, by default a bucket named `kithe-files-dev`.  Within this bucket files will be prefixed by your account/machine name (to let different developers stay out of each others way), and then further prefixed by function. (TODO, rake task to clear out your own files).

`storage_mode` key `dev_files` is also available, which stores files in the local file system instead of S3 buckets at all. It is used by default in `test`, or in `development` if you don't have AWS keys set.

And `storage_mode` `production` is default in production, with different sorts of files being stored in different S3 buckets, with those bucket names also set in env.

Regardless, object are generally stored in S3 (or file system) with paths beginning with the UUID pk of the Kithe::Asset they belong to.

## Rake tasks

We shouldn't have to use the rake tasks as much, since there is now admin web interface for creating and editing accounts. But they are still there, as they can be convenient for setting up a dev environment or perhaps bootstrapping a production environment with an admin account, or in general automating things involving users.

```shell
./bin/rake scihist:user:create[someone@example.com]
./bin/rake scihist:user:send_password_reset[someone@example.com]
./bin/rake scihist:user:test:create[someone@example.com,password]
./bin/rake scihist:user:admin:grant[someone@example.com]
./bin/rake scihist:user:admin:revoke[someone@example.com]
./bin/rake scihist:user:admin:list
```

## Global lock-out

Set `logins_disabled: true` in `./config/local_env.yml`, or somehow set a shell env variable `LOGINS_DISABLED=true` -- then restart the app to pick up the changes. Now the app won't let anyone at all log in, and won't let anyone already logged in access protected screens.

This can be useful if we need to do some maintenance that doesn't bring down the public interface, but we want to keep staff out while it goes on, so they can't edit things.

This feature was in our v1 sufia-based app, we copied it over.
