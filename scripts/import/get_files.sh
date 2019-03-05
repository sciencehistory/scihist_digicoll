REMOTE_THUMBS_PATH=/opt/export/chf-sufia/app/assets/images/collections/
SUFIA_SERVER=ubuntu@ec2-54-204-60-1.compute-1.amazonaws.com
PATH_TO_CHF_PROD_PEM_FILE=/home/eddie/.ssh/chf_prod.pem

rsync --delete \
      -e "ssh -i $PATH_TO_CHF_PROD_PEM_FILE" \
      -avz  \
      $SUFIA_SERVER:$REMOTE_THUMBS_PATH \
      /opt/import/scihist_digicoll/tmp/collection_thumb_paths/  \
      2>errors.txt

rsync --delete \
      -e "ssh -i $PATH_TO_CHF_PROD_PEM_FILE" \
      -avz  \
      $SUFIA_SERVER:/opt/export/chf-sufia/tmp/export/ \
      /opt/import/scihist_digicoll/tmp/import/  \
      2>errors.txt

chown -R digcol:deploy /opt/import/scihist_digicoll/
