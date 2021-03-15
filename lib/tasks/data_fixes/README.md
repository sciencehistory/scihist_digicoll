The `scihist:data_fixes` rake namespace, with tasks defined in ./lib/tasks/data_fixes, is mostly for one-off data migration tasks that we will run once and never need again.

Sometimes we keep them around for historical reference; other times we should trim the ones we'll never need again.

In either case, keeping them in their own namespace and directory like this is meant to minimize them getting in our way when working with regular use rake tasks, and make it clear that these are specialized and usually historical.
