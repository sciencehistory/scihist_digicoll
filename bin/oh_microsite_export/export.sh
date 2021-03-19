read -s -p "Enter the password for the local database : " DATABASE_PASSWORD

EXPORT_CMD="mysql -u `cat local_database_user.txt` -s `cat local_database_name.txt` -p$DATABASE_PASSWORD"

$EXPORT_CMD  < queries/name.sql             > data/name.json

$EXPORT_CMD  < queries/birth_date_1.sql     > data/birth_date_1.json
$EXPORT_CMD  < queries/birth_date_2.sql     > data/birth_date_2.json
$EXPORT_CMD  < queries/birth_city.sql       > data/birth_city.json
$EXPORT_CMD  < queries/birth_state.sql      > data/birth_state.json
$EXPORT_CMD  < queries/birth_province.sql   > data/birth_province.json
$EXPORT_CMD  < queries/birth_country.sql    > data/birth_country.json

$EXPORT_CMD  < queries/death_date_1.sql     > data/death_date_1.json
$EXPORT_CMD  < queries/death_date_2.sql     > data/death_date_2.json
$EXPORT_CMD  < queries/death_city.sql       > data/death_city.json
$EXPORT_CMD  < queries/death_state.sql      > data/death_state.json
$EXPORT_CMD  < queries/death_province.sql   > data/death_province.json
$EXPORT_CMD  < queries/death_country.sql    > data/death_country.json

$EXPORT_CMD  < queries/education.sql        > data/education.json
$EXPORT_CMD  < queries/career.sql           > data/career.json
$EXPORT_CMD  < queries/honors.sql           |  gsed  's/\\\"/\"/g' >   data/honors.json
