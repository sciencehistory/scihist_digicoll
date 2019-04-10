These are our Solr config files.

They are used directly in dev test, via solr_wrapper, and our `solr:` rake tasks. Due to how solr_wrapper works, if you make changes you may need to run `./bin/rake solr:clean` in development. (And stop/start your dev solr if it was already running).

In production, ansible symlinks the host-environment production Solr config to these files. At the time we are writing this, ansible only links schema.xml and solrconfig.xml, so if we need additional local solr core/collection files, we may need to adjust ansible.

These config files originally came from samvera/blacklight generators. They were updated as Solr/Blacklight best practices/requirements changed. Also some updates for local needs, for not using samvera, for using Blacklight non-traditionally, etc.
