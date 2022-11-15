# Browse-everything JS and CSS local forked copy

We use [browse-everything](https://github.com/samvera/browse-everything) to let staff choose files from a remote S3 drive for ingest.

browse-everything JS and CSS is many years old with limited maintenance put into it, and is pretty complex with some some creaky conventions. It made it hard to re-purpose in our vite environment -- or even to keep browse-everything in sprockets while moving things it depended on, like jquery and bootstrap, into vite!

So we reluctantly made a complete copy of all browse-everything JS and CSS here, so we could make the necessary changes so we could manage and deploy it with vite. For instance, browse_everything's SCSS needed to be in a SASS context with bootstrap and tried sass importing bootstrap, but we wanted to load bootstrap through vite not sprockets... and we found no good way to get browse_everything CSS into the vite SASS context with bootstrap except copying it locally.

We thereby "forked" JS and CSS from browse-everything 1.2.0.

Note that our ./browse_everthing.js includes/packages CS _and_ JS from one file; vite can handle that, and automatically writes out the neccesary html tags and/or javascript to load it all. It currently only needs to be loaded on staff pages, since that's the only place we use browse_everything.

## What if browse-everything in the future chanegs such that our forked JS/CSS no longer works with it?

* b-e is software with a pretty unclear future, it has become possibly unfeasible for the community to support it, and may not be changing much

* If it _does_ get rejuvenated, it will hopefully be a major rewrite that officially supports use through a modern JS packager like vite, and we can simply replace all this for the new supported integration.

* Otherwise, if necessary, we can fork the b-e gem itself from 1.2.0, and keep using our forked veresion with this forked JS/CSS.  Many many community members have forked b-e before, it has become perhaps the most common way to use b-e, as it has been increasingly difficult to keep b-e working for all needs.
