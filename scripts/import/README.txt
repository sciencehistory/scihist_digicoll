The scripts in this directory are used to move content out of chf-sufia and onto scihist-digicoll.

* SETUP:
    cp sample_fedora_creds.sh fedora_creds.sh

# Edit fedora_creds.sh so it contains the credentials for Fedora.
# The credentials are used during the import, to fetch the originals from Fedora.

# Note the following:
    # The scripts currently contain hard-coded hostnames for the staging chf-sufia server;
    # this will need to be changed to production later.

    # The get_files.sh and trigger_sufia_export.sh require a path to the chf_prod.pem in order to have access to the Sufia server.

    # The same files also refer to /opt/export/chf-sufia, which contains the export branch of the code.
    # Once the branch is  merged into master and deployed, those scripts can be pointed at
    # /opt/sufia-project/current/ instead.

* RUNNING THE EXPORT:
./export_and_import.sh

Invoking this script will:
    * trigger an export command on the Sufia server
    * rsync the resulting json files over
    * import the files.

* DEBUGGING: IMPORTING JUST ONE JSON FILE:
When a particular file causes the import to fail, it's often useful to
try and fix the problem, then re-import just that one file:
    ./import_one.sh the_item_s_friendlier_id
Note: once the item is imported, you still need to re-run the entire import.

* AUDITING:
To check the imported objects against the json files used to generate them, use:
    ./audit.sh
