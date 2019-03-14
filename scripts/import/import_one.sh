export RAILS_ENV='production'
export THE_ITEM=$1
chown -R digcol:deploy /opt/import/scihist_digicoll/
cd /opt/import/scihist_digicoll/
bundle exec rake scihist_digicoll:import_one
date
