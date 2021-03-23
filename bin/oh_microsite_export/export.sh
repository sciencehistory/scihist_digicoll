if [ -f "local_database_password.txt" ]; then
    DATABASE_PASSWORD=`cat local_database_password.txt`
else
    read -s -p "Enter the password for the local database : " DATABASE_PASSWORD
fi
EXPORT_CMD="mysql -u `cat local_database_user.txt` -s `cat local_database_name.txt` -p$DATABASE_PASSWORD"


#Export:
$EXPORT_CMD  < queries/birth_date_1.sql     > data/birth_date_1.json
$EXPORT_CMD  < queries/birth_date_2.sql     > data/birth_date_2.json
$EXPORT_CMD  < queries/birth_date_3.sql     > data/birth_date_3.json
$EXPORT_CMD  < queries/birth_city.sql       > data/birth_city.json
$EXPORT_CMD  < queries/birth_state.sql      > data/birth_state.json
$EXPORT_CMD  < queries/birth_province.sql   > data/birth_province.json
$EXPORT_CMD  < queries/birth_country.sql    > data/birth_country.json

$EXPORT_CMD  < queries/death_date_1.sql     > data/death_date_1.json
$EXPORT_CMD  < queries/death_date_2.sql     > data/death_date_2.json
$EXPORT_CMD  < queries/death_date_3.sql     > data/death_date_3.json
$EXPORT_CMD  < queries/death_city.sql       > data/death_city.json
$EXPORT_CMD  < queries/death_state.sql      > data/death_state.json
$EXPORT_CMD  < queries/death_province.sql   > data/death_province.json
$EXPORT_CMD  < queries/death_country.sql    > data/death_country.json

$EXPORT_CMD  < queries/education.sql        > data/education.json
$EXPORT_CMD  < queries/career.sql           > data/career.json

# TODO: fix this bug.
$EXPORT_CMD  < queries/honors.sql           |  gsed  's/\\\"/\"/g' >   data/honors.json


# Verification: contains name, source URL, and interview number
$EXPORT_CMD  < queries/name.sql             > data/name.json

# We'll use this for the crosswalk to FAST headings
$EXPORT_CMD  < queries/institutions.sql     > data/institutions.txt
