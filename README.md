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
* `mediainfo` installed for fallback contnet type detection -- on MacOS, `brew install mediainfo`
* vips installed --  on MacOS `brew install vips`
* Have your AWS credentials put in a file called `aws_secrets.json` at the project's root directory. This is needed for deploying code.

```bash
$ git clone git@github.com:sciencehistory/scihist_digicoll.git
$ cd scihist_digicoll
$ bundle install
$ yarn install
$ rake db:setup
```

Start a development Solr instance with `./bin/rake solr:start`.

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

We are using webpacker (an ES6-style JS toolchain, supported by Rails 5.1+, default/recommended in Rails5) for some javascript, but still using sprockets asset pipeline for other javascript. Our layouts will generally load a webpacker pack (with `javascript_include_pack`) as well as a sprockets compiled file (with `javascript_include_file`). Both will be compiled by `rake assets:precompile` in production, and automatically compiled in dev.

We are still using sprockets to control our CSS (scss), **not** webpacker.

* All _local javascript_ is controlled using webpacker, and you should do that for future JS.

* Some general purpose dependencies that probably *could* be via webpacker are at the moment still via sprockets (and gem dependencies to provide the JS, rather than npm packages).
  * jQuery
  * Bootstrap
  * popper.js for Bootstrap
  * rails-ujs

* Some more rails-y dependencies are also still provided by sprockets asset pipeline, in some cases it is tricky to figure out how to transition to webpacker (or may not be possible)
  * cocoon (used for adding/removing multi-values in edit screens; may not be avail as npm package)
  * blacklight (theoretically available as an npm package, but I found it's [instructions](https://github.com/projectblacklight/blacklight/wiki/Using-Webpacker-to-compile-javascript-assets) somewhat obtuse and weird and was not feeling confident/comfortable with them)
  * blacklight_range_limit (may not be avail as npm package instead of ruby gem/sprockets)
  * browse-everything (not avail as npm package instead of ruby gem/sprockets)

* You can look at `./app/assets/javascripts/application.js` to see what dependencies are still being provided via the sprockets-asset-pipeline-compiled application.js file, usually with src from a rubygem.

* uppy (JS for fancy file upload func) is still being loaded in it's own separate script tag from remote CDN (see admin.html.erb layout). This is recommended against by the uppy docs, and we should transition to providing via webpacker and `import` statement, just including the parts of uppy we need, but haven't figured out how to do that yet (including uppy css)

* We have not at present experimented with running `./bin/webpack-dev-server` separately in dev (and it is likely not working, pending update to webpacker 4), we're just letting Rails do it the slower but just-works way.

Some references I found good for understanding webpacker in Rails:
* https://medium.com/@coorasse/goodbye-sprockets-welcome-webpacker-3-0-ff877fb8fa79

### Development docs

Our ActiveRecord models, with some other support, come from [kithe](https://github.com/sciencehistory/kithe), which has pretty good docs which should be useful.

Some other interesting/complicated sub-systems we've written documentation for:

* [On-demand whole-work derivatives](docs/on_demand_derivatives.md)

### Interesting gem dependencies

* [kithe](https://github.com/sciencehistory/kithe) of course provides a lot of digital-collections domain-specific functionality
  * which itself uses [attr_json](https://github.com/jrochkind/attr_json/) for modelling attributes as a single json column in the db, and [shrine](https://shrinerb.com) for file handling.
* [devise](https://github.com/plataformatec/devise) is used for authentication/login
* [access-granted](https://github.com/chaps-io/access-granted) is used for some very simple authorization/permissions (right now just admins can do some things other logged in staff can not)
* [blacklight](https://github.com/projectblacklight/blacklight) We are currently using Blacklight
  for the "end-user-facing" search, although we are using it in a very limited and customized fashion, not including a lot of things the BL generator wanted to include in our app, that we didn't plan on using.

### Writing tests

Some things we have configured in our `rails_helper.rb` to make writing tests easier and the application settings more configurable.

#### browser tests

Rspec `system` tests are configured to run with the `:selenium_chrome_headless` driver for real browser testing. If you tag a system test `js: false`, it will still run with `rack_test`, not a real browser.

If instead of running in a headless browser, you want to run in a real browser you can see being automated on your screen, run as `SHOW_BROWSER=true ./bin/rspec [whatever]`.

#### a logged in user

If you tag a test with `logged_in_user: true`, the test framework will create a random user and set it as the logged in user with devise, so your tests have a logged in user available.

     describe "something", logged_in_user: true do ...
     # or
     it "does something", logged_in_user: true do ...

You can also do `logged_in_user: :admin` to get a user with `admin?` permissions. (superusers)

#### ActiveJob queue adapter

Rails by default, in the test environment, will run any background ActiveJobs with it's `:async` adapter -- they are run in a separate thread in process, still async.

Other available ActiveJob adapters are

* `:inline` -- run the job synchronously, inline, so it is is complete before going to the next code line. Using this setting is one way to get our shrine file promotion and derivatives creation have happened before going to the next line of the test.
* `:test` -- don't run the ActiveJob at all, but there are Rails test methods to test that it was indeed enqueued, with the arguments expected.

We provide test setup to let you switch ActiveJob queue adaptors for particular test or test context:

    describe "something", queue_adapter: :inline
    # or
    it "does something", queue_adapter: :test

#### solr indexing callbacks

By default, the test environment disables our automatic callbacks that index models to solr on save. If you'd like to enable them for a test context or example, just supply `indexable_callbacks: true`

#### Real Solr

If you have tests that require a real solr to be running (such as system/integration tests in parts of the app that use solr), specify `solr: true` and `solr_wrapper` will be used to (install if needed and) launch a solr. Solr will only be launched when/if a test is encountered that is so tagged, but will only be launched once (and shut down on termination) if there are multiple tests requiring it.

#### Testing with S3

Normally all tests are run against local file system storage instead of S3. (And that is what
travis tests).

But if you want to manually run some tests against a real S3, make sure you have S3 credentials
set up, and you can run against dev_s3 mode:

    WEBMOCK_ALLOW_CONNECT=true STORAGE_MODE=dev_s3 S3_DEV_PREFIX="jrochkind-tests" ./bin/rspec whatever

In dev_s3, all files are put in our shared dev bucket. The above command manually sets an S3_DEV_PREFIX, so it won't mess with or accidentally delete your ordinary dev files.

## Production deployment

We deploy to AWS, the deployment is done _mostly_ automatically by some ansible playbooks:
* https://bitbucket.org/ChemicalHeritageFoundation/ansible-inventory/src/master/
* https://bitbucket.org/ChemicalHeritageFoundation/ansible-inventory/src/master/create_kithe.yml
* https://bitbucket.org/ChemicalHeritageFoundation/ansible-inventory/src/master/create_kithe_s3.yml

There is some additional manual setup for S3 buckets:
* https://chemheritage.atlassian.net/wiki/spaces/HDCSD/pages/516784129/S3+Bucket+Setup+and+Architecture

## File storage notes

Files are handled by [kithe/shrine](https://github.com/sciencehistory/kithe/blob/master/guides/file_handling.md), and in production stored in S3 buckets. There are a number of different buckets we use for different classes of files in production (which includes staging), documented in the [Atlassian wiki](https://chemheritage.atlassian.net/wiki/spaces/HDCSD/pages/516784129/S3+Bucket+Setup+and+Architecture).

There are different file storage modes available for convenience in development/test. Which can be set with our [env key](./app/lib/scihist_digicoll/env.rb) `storage_mode`. In development, you should set env keys `aws_access_key_id` and `aws_secret_access_key` to AWS keys with development access. And then the storage mode will default to `dev_s3` -- which means files of all types are stored in a single bucket, defined by env key `s3_dev_bucket`, by default a bucket named `kithe-files-dev`.  Within this bucket files will be prefixed by your account/machine name (to let different developers stay out of each others way), and then further prefixed by function. (TODO, rake task to clear out your own files).

`storage_mode` key `dev_files` is also available, which stores files in the local file system instead of S3 buckets at all. It is used by default in `test`, or in `development` if you don't have AWS keys set.

And `storage_mode` `production` is default in production, with different sorts of files being stored in different S3 buckets, with those bucket names also set in env.

Regardless, object are generally stored in S3 (or file system) with paths beginning with the UUID pk of the Kithe::Asset they belong to.

## Deployment

We use [capistrano](https://github.com/capistrano/capistrano) to deploy our application.

    bundle exec cap staging deploy
    bundle exec cap production deploy

We have set up capistrano to auto-discover what servers to deploy to, by using AWS api to list our EC2 servers, with certain tags. See our custom [CapServerAutodiscover](./config/deploy/lib/cap_server_autodiscover.rb) module for details.

To make this work, you need to have AWS credentaisl available -- for now, we use a special set of credentails just for cap deploy, the 'cap_deploy' user. You should get the credentails from Dan or AWS IAS console, and put them in a file at `./cap_aws_credentials.yml`. See/copy the example at [./cap_aws_credentials.yml.example](./cap_aws_credentials.yml.example).

To list servers auto-discovered from EC2 without doing a deploy, run `cap staging list_ec2_servers` or `cap production list_ec2_servers`.

When deploying to a new server add the flag solr_restart=true to the deploy so Solr performs a full restart and loads the configuration files. Normal deploys only reload Solr.

## Rake tasks

### Solr Data

* `./bin/rake scihist:solr:reindex` to reindex all Works and Collections in Solr.
* `./bin/rake scihist:solr:delete_orphans` deletes things from Solr that no longer exist in the db. Ordinarily not required, but if things somehow get out of sync.
* `./bin/rake scihist:solr:delete_all` Meant for development/test only, deletes all documents from Solr.

You can run these tasks on a remote deploy environment (will actually run on server identified with capistrano "jobs" role) using capistrano, eg:

    bundle exec cap staging invoke:rake TASK="scihist:solr:reindex scihist:solr:delete_orphans"

So no need to actually `ssh` to production environment to trigger a reindex or cleanup. When executing via cap, the "progress bar" is a bit wonky (and not a bar), but it works.

### Derivatives

We have some rake tasks from [kithe] for managing derivatives. Most commonly useful, to
bulk create all missing derivatives:

    ./bin/rake kithe:create_derivatives:lazy_defaults

Creates all defined derivatives that don't already exist. There are other ways to create
only certain defined derivatives, lazily or not. (May need some tweaking). See
https://github.com/sciencehistory/kithe/blob/master/guides/derivatives.md#rake-tasks

DZI's are not handled with kithe's ordinary derivative function (see ./app/models/dzi_files.rb),
so have separate rake task to bulk create only DZI that do not exist, checking first with
an S3 api request:

    ./bin/rake scihist:lazy_create_dzi

Or to force-create DZI for specific assets named by friendlier_id:

    ./bin/rake scihist:create_dzi_for[11tdi3v,2eh2i28]

### Dev/test solr

We use [solr_wrapper](https://github.com/cbeer/solr_wrapper) to conveniently install and run a Solr for development and tests. (In production, the host environment provides the solr, but ansible is set up to use our solr core configuration in ./solr/config the same as solr_wrapper does in dev/test).

To start a development instance of Solr you can use with the development Rails app, run:

    ./bin/rake solr:start

It will stay up until the process is killed, or you can stop it with `./bin/rake solr:stop`. See  also `solr:status`, `solr:restart`, and conveniently `./bin/rake solr:browser` to open a browser window pointing to solr console (MacOS only).

Configuration for solr_wrapper is at `./.solr_wrapper.yml`


### Account management

We shouldn't have to use account management rake tasks as much, since there is now admin web interface for creating and editing accounts. But they are still there, as they can be convenient for setting up a dev environment or perhaps bootstrapping a production environment with an admin account, or in general automating things involving users.

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
