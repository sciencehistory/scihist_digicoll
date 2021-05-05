if [ -f "local_database_password.txt" ]; then
    DATABASE_PASSWORD=`cat local_database_password.txt`
else
    read -s -p "Enter the password for the local database : " DATABASE_PASSWORD
fi

EXPORT_CMD="mysqlsh -u `cat local_database_user.txt` --database=`cat local_database_name.txt` --password=$DATABASE_PASSWORD --sql --result-format=json/array"
EXPORT_DESTINATION=/tmp/ohms_microsite_import_data

# A text file for converting institution names to FAST headings
$EXPORT_CMD  < queries/institutions.sql     > $EXPORT_DESTINATION/institutions.txt

# URL mappings: Drupal URL aliases to friendlier_ids
$EXPORT_CMD  < queries/url.sql             > $EXPORT_DESTINATION/url.json
# URL mappings: Drupal File urls to friendlier_ids
$EXPORT_CMD  < queries/file.sql             > $EXPORT_DESTINATION/file.json


# Mapping check: contains name, source URL, source URL alias, and interview number
$EXPORT_CMD  < queries/name.sql             > $EXPORT_DESTINATION/name.json

# Biographical data export:
$EXPORT_CMD  < queries/birth_date.sql       > $EXPORT_DESTINATION/birth_date.json
$EXPORT_CMD  < queries/birth_city.sql       > $EXPORT_DESTINATION/birth_city.json
$EXPORT_CMD  < queries/birth_state.sql      > $EXPORT_DESTINATION/birth_state.json
$EXPORT_CMD  < queries/birth_province.sql   > $EXPORT_DESTINATION/birth_province.json
$EXPORT_CMD  < queries/birth_country.sql    > $EXPORT_DESTINATION/birth_country.json

$EXPORT_CMD  < queries/death_date.sql       > $EXPORT_DESTINATION/death_date.json
$EXPORT_CMD  < queries/death_city.sql       > $EXPORT_DESTINATION/death_city.json
$EXPORT_CMD  < queries/death_state.sql      > $EXPORT_DESTINATION/death_state.json
$EXPORT_CMD  < queries/death_province.sql   > $EXPORT_DESTINATION/death_province.json
$EXPORT_CMD  < queries/death_country.sql    > $EXPORT_DESTINATION/death_country.json

$EXPORT_CMD  < queries/education.sql        > $EXPORT_DESTINATION/education.json
$EXPORT_CMD  < queries/career.sql           > $EXPORT_DESTINATION/career.json
$EXPORT_CMD  < queries/honors.sql           > $EXPORT_DESTINATION/honors.json

# Interviewee portraits
$EXPORT_CMD  < queries/image.sql             > $EXPORT_DESTINATION/image.json

# Interviewers and profiles:
$EXPORT_CMD  < queries/interviewer.sql               > $EXPORT_DESTINATION/interviewer.json
$EXPORT_CMD  < queries/interviewer_2.sql             > $EXPORT_DESTINATION/interviewer_2.json
$EXPORT_CMD  < queries/interviewer_profile.sql       > $EXPORT_DESTINATION/interviewer_profile.json

cp json_mappings/fast_mappings.json                    $EXPORT_DESTINATION/all_transforms.json