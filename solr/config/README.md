These are our Solr config files.

They are used directly in local dev and test, via functionality from the solr_wrapper gem, and our `solr:` rake tasks which control solr_wrapper. Our CI run also uses those rake tasks/solr wrappe to make sure solr is installed and running for CI.

## Local changes to solr config

Due to how solr_wrapper works, if you make changes here, you might need to get solr_wrapper to refresh the config for the installed dev and tmp solrs. You can do so, then restart solr, in test by running eg:

   RAILS_ENV=test ./bin/rake solr:clean solr:start

Or for development:

  ./bin/rake solr:clean solr:start

solr_wrapper installed Solr configs should be at:

* `./tmp/solr_test/server/solr/scihist_digicoll_test/conf`
* `./tmp/solr_development/server/solr/scihist_digicoll_development/conf/`

In case you need to develop with a quicker iteration loop than waiting for the `clean` and want to edit files directly -- but you should always use the `clean` task at the end to make sure everything is consistent between what's in our git source dir (and committed) and what's actually in the running solr.

## SearchStax

(deploy infrastructure we are moving to)

The `scihist:solr_cloud:sync_configset` rake task will use Solr Cloud API to
ensure that Solr identified by our SOLR_URL config is using the current on
disk config in this directory. It will sync any files in this directory.

It uses a naming pattern that puts a fingerprint digest of the config directory
at the end of the Solr cloud "config set" name to aid in management.

When on heroku, this rake task is configured to run as part of heroku release phase.
You can also of course run it manually in any location that has the config files
on disk you'd like to set, and where SOLR_URL is set properly (likely with
http basic auth)

    SOLR_URL=https://user:pass@somehost.org/solr/collection_name ./bin/rake scihist:solr_cloud:sync_configset

...Will sync the solr config directory where you are running it.

For more on SearchStax, see our wiki on [Searchstax Solr](https://chemheritage.atlassian.net/l/c/NRZz1d6v)


## History of these config files

These config files originally came from samvera/blacklight generators. They were updated as Solr/Blacklight best practices/requirements changed. Also some updates for local needs, for not using samvera, for using Blacklight non-traditionally, etc.  There may be things in here we inherited
that are not necessarily intentional or optimal.


## Before Heroku: self-managed EC2 via Ansible (OBSOLETE)

In production, ansible symlinked the host-environment production Solr config to these files. Ansible only linked schema.xml and solrconfig.xml.
