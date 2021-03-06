These are our Solr config files.

They are used directly in dev test, via solr_wrapper, and our `solr:` rake tasks. Due to how solr_wrapper works, if you make changes you may (or may not) need to run `./bin/rake solr:clean` in development. (And stop/start your dev solr if it was already running).

## Self-managed EC2 via Ansible

(Our original deploy infrastructure)

In production, ansible symlinks the host-environment production Solr config to these files. At the time we are writing this, ansible only links schema.xml and solrconfig.xml, so if we need additional local solr core/collection files, we may need to adjust ansible.

Also,

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
