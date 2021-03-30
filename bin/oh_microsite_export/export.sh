if [ -f "local_database_password.txt" ]; then
    DATABASE_PASSWORD=`cat local_database_password.txt`
else
    read -s -p "Enter the password for the local database : " DATABASE_PASSWORD
fi

EXPORT_CMD="mysqlsh -u `cat local_database_user.txt` --database=`cat local_database_name.txt` --password=$DATABASE_PASSWORD --sql --result-format=json/array"
EXPORT_DESTINATION=/tmp/ohms_microsite_import_data


# A text file for converting institution names to FAST headings
$EXPORT_CMD  < queries/institutions.sql     > $EXPORT_DESTINATION/institutions.txt

# Mapping check: contains name, source URL, and interview number
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