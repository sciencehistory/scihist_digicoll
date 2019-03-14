The scripts in this directory are used to move content out of chf-sufia and onto scihist-digicoll.

## Exporting
First, get the data out of Sufia. On the Sufia jobs server, as root, run `/opt/export/export.sh` .
## Copying the files over
On the scihist-digicoll server, run `/opt/import/scihist_digicoll/scripts/import/get_files.sh`
## Importing
`/opt/import/scihist_digicoll/scripts/import/import.sh`
## Regenerating derivatives
The import doesn't currently generate derivatives for newly-imported items. If there are new files in the import whose derivatives need to be generated, you can run `/opt/import/scihist_digicoll/scripts/import/generate_derivatives.sh`

### Notes
* The scripts currently contain hard-coded hostnames for the staging chf-sufia server; this will need to be changed to production later.
* `get_files.sh` and `trigger_sufia_export.sh` require a path to a chf_prod.pem file in order to have access to the Sufia server.
* `trigger_sufia_export.sh` will be the nightly automated export-and-import script. Its contents are currently commented out because it contains a bug.
* The same files also refer to `/opt/export/chf-sufia`, which contains the export branch of the code. Once the branch is permanently merged into master and deployed to production, those scripts can be pointed at /opt/sufia-project/current/ instead.

## Importing a single json file to fix a bug
When a particular file causes the import to fail, it's often useful to try fixing the problem, then re-import just that one file: `/opt/import/scihist_digicoll/scripts/import/import_one.sh friendlier_id`
*Note: once you fix the bug and succesfully import the item, you still need to re-run the entire import.*

## Auditing
To check the imported objects against the json files used to generate them: `/opt/import/scihist_digicoll/scripts/import/audit.sh`
