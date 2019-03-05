# ideally we would trigger this using a rake task ...
# cd /opt/import/scihist_digicoll/
# bundle exec cap staging invoke:rake TASK=chf:export

# but for now, let's just trigger the export via ssh:
ssh -i ~eddie/.ssh/chf_prod.pem  -t ubuntu@ec2-54-204-60-1.compute-1.amazonaws.com /opt/export/export.sh
