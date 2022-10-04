# Science History Institute Digital Collections

[![Build Status](https://github.com/sciencehistory/scihist_digicoll/workflows/CI/badge.svg?branch=master)](https://github.com/sciencehistory/scihist_digicoll/actions?query=workflow%3ACI+branch%3Amaster)

The current live/production Science History Institute Digital Collections application. A rewrite of a previous app based on sufia, this one is not.

This one is based on the [kithe](https://github.com/sciencehistory/kithe) toolkit, which was developed in tandem with this app.

## Development Setup

To set up a development instance on your workstation.

### Prerequisites

* (MacOS) You're going to want homebrew, which will also take care of making sure you have a C compiler toolchain to install native C gems. https://brew.sh/
* While not technically required just to run the app, you're going to want `git`. MacOS, `brew install git`.
* ruby installed (I like using chruby and ruby-build to install/manage rubies, some like rvm)
* Postgres version 14 or higher, installed and running -- on MacOS, I like https://postgresapp.com/
* `yarn` and `node` installed for managing webpacker JS dependencies -- on MacOS, `brew install node yarn`.
* `mediainfo` installed for fallback contnet type detection -- on MacOS, `brew install mediainfo`
* vips installed --  on MacOS `brew install vips`
* ffmpeg installed -- on MacOS `brew install ffmpeg`
* You'll need Java installed to run Solr. If you don't already have it, on MacOS `brew install java`, then follow post-install instructions, such as `sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk`



### Install and setup the app

```bash
$ git clone git@github.com:sciencehistory/scihist_digicoll.git
$ cd scihist_digicoll
$ bundle install
$ yarn install
$ rake db:setup
```

If you have problems installing the `pg` gem, which I did on an M1 Mac running MacOS 12, this worked:

* brew install libsq
* follow the post-install instructions about modifying $PATH to put libsq on it -- this gives you utilities like `psql`, and also made install of `pg` gem work.

### Create an admin user for yourself

    ./bin/rake scihist:user:test:create[email_addr,password] scihist:user:admin:grant[email_addr]

Now you can login in a running app at probably `http://locahost:3000/login` with those credentials.

### AWS credentials

Configure your local machine with AWS credentials using standard AWS ways, such as the `aws configure`. https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html

We recommend _not_ storing "super-user" credentials as your "default" profile. Instead,
store credentials with limited access. Such as a `dev` user set up for you personally,
using our IAM group/shared policy `dev_users`.

You may also need to configure the aws region (`us-east-1`).

If you do want to run the Rails app with a different AWS profile, just set `AWS_PROFILE` env var when running a rails command -- on command line, in shell with `export`.

* If you don't want your dev app to use AWS for file storage, you can set `STORAGE_MODE` env to `dev_file`, and you may not need AWS credentials.

### Start development instance

Start a development Solr instance with `./bin/rake solr:start`.

Run app with `./rails server`, it will be available at `http://localhost:3000`.

### Deploying

To interact with our deployment infrastructure on [heroku](heroku.com), see [Heroku Developer Setup](https://chemheritage.atlassian.net/l/c/FsTqq6DV) in our wiki.

### To use githoooks in repo

There's a pre-commit hook in the repo to try and **catch you from accidentally
commiting AWS keys**, to use, after `git clone` set your local copy to use the
hooks that come with the repo:

    git config core.hooksPath .githooks


### Local Env

If you want to change defaults to our config/env variables (managed by `ScihistDigicoll::Env`), you can set them in your shell ENV (via .bash_profile, on the command line, or otherwise), OR you can create a `local_env.yml` or `local_env_development.yml` file. The latter may make sense if you don't want your particular settings to effect the test environment.

For instance, you can switch between whether files are stored in dev-s3 mode, or in the local file system, with:

    STORAGE_MODE=dev_file rails server

Or by putting in a `local_env[_development].yml` file:

    storage_mode: dev_file

### Running tests

Start the test solr (if you don't, test setup should do it for you if needed, but this is cleaner):

  RAILS_ENV=test ./bin/rake solr:start

Then:

  ./bin/rspec

(You can shut down or restart test solr with eg `RAILS_ENV=test ./bin/rake solr:stop` or `:restart`, as well as check on it's status with `:status`)

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
* [view_component](https://github.com/github/view_component) we use extensively for organizing
  our view layer logic. We also still have it mixed with plenty of standard partials, for legacy
  reasons. Going forward, we'll use ViewComponents wherever it makes sense.
* [devise](https://github.com/plataformatec/devise) is used for authentication/login
* [access-granted](https://github.com/chaps-io/access-granted) is used for some very simple authorization/permissions (right now just admins can do some things other logged in staff can not)
* [blacklight](https://github.com/projectblacklight/blacklight) We are currently using Blacklight
  for the "end-user-facing" search, although we are using it in a very limited and customized fashion, not including a lot of things the BL generator wanted to include in our app, that we didn't plan on using.
* [lockbox](https://github.com/ankane/lockbox) for encrypting our patron data eg in Oral History
  requests. For rotating keys should private key need to be changed, see https://github.com/ankane/lockbox/issues/35

### Task to copy a Work from staging to your local dev instance

   ./bin/rake heroku:copy_data[$work_friendlier_id]

Will copy a work (and all it's children, and all derivatives of all) from staging to your local dev instance. It will keep pk's and friendlier_id's constant, so you need to make sure you don't have anything conflicting already in your local db.

It can be slow, and the code has several hacky workarounds to make it work, but it works.

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

Our app is set in the test environment to by default use the ActiveJobs  `:test` adapter --
background jobs will not actually run, just be registered as queued in :test adapter, but there
are Rails test methods to test it was indeed enqueued.

Other available ActiveJob adapters are

* `:inline` -- run the job synchronously, inline, so it is is complete before going to the next code line. Using this setting is one way to get our shrine file promotion and derivatives creation have happened before going to the next line of the test.
* `:async` -- run the ActiveJobs actually in the background, in an async thread. You probably do not want this setting, it's hard to test and can have unpredictable interactions with the suite.

We provide test setup to let you switch ActiveJob queue adaptors for particular test or test context:

    describe "something", queue_adapter: :inline
    # or
    it "does something", queue_adapter: :inline

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

## Notes on File Security and Derivative Storage Type

In production, our originals are stored in an S3 bucket that has public access blocked. After the app determines a user is authorized to access an original, a temporary signed S3 url is delivered for (eg) a download link, direct from S3.

However, our _derivatives_ (eg thumbnails) are stored in an S3 bucket with public access. This allows us to use long-lasting persistent public S3 URLs to refer to these, that are the same for all pages/users. These are higher performance to generate than signed; also they can be cached, and their contents can be cached, in caches shared between page accesses and users. For these reasons it would also in the future be trivial to use with a CDN for higher performance and scalability.

This is true whether the Asset is _published_ or not; its derivatives are in public-accessible S3.  This allows us to avoid having to try copying files from one bucket to another when publication status changes; it would be very hard to 'guess' at URLs for these unpublished things; and if someone did get a URL for pre-published materials they aren't normally particularly sensitive.

But for certain Assets which really _are_ sensitive (eg certain oral histories), the app supports marking `derivative_storage_type: "restricted"`.  For Assets so marked, derivatives will be stored in a different bucket with public access blocked. Signed S3 URLs can be delivered by the app for authorized users.

In addition to marking an asset for restricted derivatives on ingest, its derivative storage type can be changed by admins at any time. When an asset is moved to derivatives storage, a variety of files in public storage need to be deleted, including on backup S3 buckets, and s3 version history. The `EnsureCorrectDerivativeStorageTypeJob` is responsible for this, after being triggered by an `after_update_commit` callback on Asset model.

`derivative_storage_type: restricted` is not meant to be used with `published` assets -- there is no point to it, and it would be a performance problem.

DZI files (for our viewer pan and zoom) are not supported for `derivative_storage_type: "restricted"`, as it would be challenging to get non-public DZI files to the viewer in an efficient way, and we don't have a use case at present.

We have a nightly job intending to verify internal consistency of derivative storage type settings, and its report can be seen in Admin dashboard at `/admin/storage_report`.

## Deployment

We deploy to heroku.

See on our wiki:

* [Heroku Developer Setup](https://chemheritage.atlassian.net/wiki/spaces/HDC/pages/1956806658/Heroku+developer+setup) -- with instructions for pushing code to heroku.
* [Heroku operational components overview](https://chemheritage.atlassian.net/wiki/spaces/HDC/pages/1915748368/Heroku+Operational+Components+Overview) -- look at notes on preboot.

In this repo, the [heroku Procfile](./Procfile), including "release" phase for things that happen on deploy. https://devcenter.heroku.com/articles/release-phase


## Rake tasks

### Solr Data

* `./bin/rake scihist:solr:reindex` to reindex all Works and Collections in Solr.
* `./bin/rake scihist:solr:delete_orphans` deletes things from Solr that no longer exist in the db. Ordinarily not required, but if things somehow get out of sync.
* `./bin/rake scihist:solr:delete_all` Meant for development/test only, deletes all documents from Solr.

You can easily run these tasks on a remote deploy environment with heroku

    heroku run rake scihist:solr:reindex scihist:solr:delete_orphans
    heroku run rake scihist:solr:reindex scihist:solr:delete_orphans -r production

See [Heroku Developer Setup](https://chemheritage.atlassian.net/wiki/spaces/HDC/pages/1956806658/Heroku+developer+setup)


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

Another exception is combined audio derivatives for oral histories. To create those (lazily):

    ./bin/rake rake scihist:create_full_length_audio_derivatives

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

## Thanks

<img src="https://www.browserstack.com/images/layout/browserstack-logo-600x315.png" width="280"/>

[BrowserStack](http://www.browserstack.com) supports us with [free access for open source](https://www.browserstack.com/open-source).

<hr>

<img src="https://cdn.buttercms.com/H1XnscpwTVC4gsjtyJ2U" width="180" />

[Scout APM](https://ter.li/h8k29r) supports us with free access for open source.
