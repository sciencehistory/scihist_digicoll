export RAILS_ENV='production'
chown -R digcol:deploy /opt/import/scihist_digicoll/
cd /opt/import/scihist_digicoll/
bundle exec rake scihist_digicoll:import
