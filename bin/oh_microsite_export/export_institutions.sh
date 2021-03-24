if [ -f "local_database_password.txt" ]; then
    DATABASE_PASSWORD=`cat local_database_password.txt`
else
    read -s -p "Enter the password for the local database : " DATABASE_PASSWORD
fi
EXPORT_CMD="mysql -u `cat local_database_user.txt` -s `cat local_database_name.txt` -p$DATABASE_PASSWORD"

# We'll use this for the crosswalk to FAST headings
$EXPORT_CMD  < queries/institutions.sql     > data/institutions.txt
