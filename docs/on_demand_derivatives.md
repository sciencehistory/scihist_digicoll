# On-demand whole-work derivatives

Our app offers derivatives of a _work_ composed of all the member images of the work. A Zip file of full-resolution JPGs of all children; a PDF file of large-sized JPGs composed into pages to make a whole-work PDF.

These are inconvenient in a few ways:

* The derivatives are very large (storage cost, and general inconvenience with backup/recover and shuffling things around)
* They can take a relatively long time to create
* If a work has it's child images added/removed/changed, a previously created derivative is now invalid.

To try to deal with these inconveniences we:

* Create these derivatives _on-demand_ when requested, rather than try to create/store them all up front.
* They are stored to an S3 bucket for "on demand derivatives" which is set to automatically delete files that have not been accessed in some time, so it can be used as a sort of 'cache' so if lots of users/requests are asking for the same one, it won't have to be created fresh each time, but we also won't try to store them all forever.
* A `checksum` is computed based on source contents, and included in the filename/tracking DB record. So if the checksum changes, an old-checksumed derivative will be abandoned (and eventually reclaimed by bucket lifecycle rules deleting things not accessed in a while)
* Javascript is provided on download links that can (using a back-end controller that returns Json) check on status of derivative creation, kick off creation if the file doesn't yet exist, and display a _progress bar_ if it's in progress of being created. Will redirect to location of derivative directly on S3 if it already exists, or once it exists.

The software pieces involved are:

* `OnDemandDerivative` -- an ActiveRecord model representing a given derivative (with a given checksum).
  * Just because the OnDemandDerivative model exists doesn't mean the file is really on S3, it may have been reclaimed if not used in a while. OnDemandDerivative#file_exists? can check.
  * The OnDemandDerivative has status information (success, error, in_progress), as well as progress information (x completed of y total).
* `OnDemandDerivativeCreator` -- has logic to implement `find_or_create_record`, returning an OnDemandDerivative record. If needed, will kick off creation of actual derivative (in-progress) in a concurrency-safe way.
* `OnDemandDerivativeController` -- it's one action method will call `OnDemandDerivativeCreator#find_or_create_record` to make sure a derivative is either available or kick off creation. And then return a JSON representation of derivative status/progress that front-end JS can use.
  * Will also update the OnDemandDerivative record with progress information, for a progress bar! We generally try to increment the progress bar as we add each child to the whole-work derivative.
* `scihist_on_demand_downloader.js` The (Jquery-based) Javascript to handle displaying a progress bar if appropriate, and redirecting to actual derivative download, once/if it's available, as reported by `OnDemandDerivativeController` status report.
* `WorkZipCreator` and `WorkPdfCreator` actually create the derivatives, triggered by `OnDemandDerivativeCreator`, as discovered from on-demand derivative type information registered in `OnDemandDerivative.derivative_type_definitions` class method.
* `OnDemandDerivativeCreatorJob` an ActiveJob that does the actual derivative creation, in a bg job, to not take up web workers.

## Extract?

There are kind of a lot of moving parts, although it ends up working out pretty well, and at this point is probably pretty generalizable. Should we extract this code to somewhere other institutions/developers could use it? Perhaps kithe?
