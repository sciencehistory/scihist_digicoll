echo
echo "Are you sure you want to sync the production S3 files"
echo "(both originals and derivatives) to staging? [Y/N]"
read -p ">  " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    aws s3 sync s3://scihist-digicoll-production-originals s3://scihist-digicoll-staging-originals
    aws s3 sync s3://scihist-digicoll-production-derivatives s3://scihist-digicoll-staging-derivatives
else
    echo "Kthxbye"
fi