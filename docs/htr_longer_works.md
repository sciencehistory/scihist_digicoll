# Handwriting transcription for longer works

*Draft for discussion, November 2026.*

We use Google's Gemini model to make AI transcriptions of handwritten works. Today we can only do this for works of 10 pages or fewer. This document proposes how to extend it to much longer works. During a trial phase we would practice on works of 30 to 100 pages, and the long-term goal is books of up to about a thousand pages.

It describes where we are now, the constraints that shaped the proposal, the workflow we have in mind, and the changes needed to get there. The order of the work, and how it splits into pull requests, will be covered separately.

## Terms

- **Request:** the ask to transcribe one work, and the record of how that went: when it ran, which model and version of our code it used, and whether it succeeded.
- **Quire:** a run of consecutive pages from one work, sent to Gemini together in a single request over the network. (We borrow the bookbinding term for a gathering of leaves. "Chunk" already means something else in our code.) A long work is split into many quires, and every page belongs to exactly one quire.
- **Context page:** a page sent along with a quire only to help Gemini with continuity, usually the last page of the quire before it. Gemini can read it, but does not transcribe it; it is transcribed by its own quire.
- **Guide:** notes about a whole work that Gemini prepares before transcription starts. It covers names, places, abbreviations, languages and hands, and how the work is organized. Every quire gets a copy.

## Where we are now

- Staff choose "handwriting transcription" as a work's text extraction mode. A background process notices this and queues a request for the work.
- The request sends **all of the work's pages to Gemini at once**, together with the work's description and our instructions. Gemini returns a transcript for each page, plus notes about the work as a whole and about individual pages.
- Each page's transcript is stored on that page (the "asset"). From there it appears in the public "AI Transcription" tab (behind a feature flag) and is searchable.
- The record of the request is stored inside the work's own metadata. It holds its status, any error, Gemini's notes, the model used and the version of our code. Only the most recent request is kept.
- Works with **more than 10 pages are refused**. The 10-page limit keeps each request within what Gemini handles reliably in one go, and limits the cost of a mistake.
- Staff can request a new transcription, or delete the transcription, from the work's admin page.

## Constraints that shaped this proposal

- **Gemini costs money, and its results can't be reproduced exactly.** Unlike our older OCR, we can't freely rerun it. We should only redo what failed, and we should keep a clear record of what was produced, when, and how.
- **There's a limit to how many pages one request can take.** A thousand-page book has to be split into many requests, so we need a way of keeping track of all the pieces.
- **Splitting a work loses context.** Gemini transcribes a page better when it can see what came before it: a sentence that runs across a page break, a name it has already worked out, an abbreviation it has already seen expanded. Each piece needs some of that context back.
- **Pieces that depend on each other are fragile.** If each piece had to wait for the transcript of the piece before it, a thousand-page book would become a single chain of about 100 steps. One failure would block everything after it, and one misreading could be copied forward through the rest of the book.
- **Time matters much less than quality.** Transcribing a long manuscript by hand can take a scholar years. Hours or even days of processing are fine if the results are good. We would still like the design to allow pieces to run at the same time, but we won't sacrifice quality for speed.
- **The transcripts belong to the pages.** Once a transcript is finished, it is metadata of the page it transcribes. Requests and quires exist only to run the process and to record provenance (how each transcript was made). The public site and search should never need to look at them.
- **Storing request records in the work's metadata has caused bugs.** Every status update rewrites the work, which led to a bug where finished transcripts didn't reach search. Request records should be stored on their own.
- **Existing transcriptions must keep working.** Works transcribed under the current system need to continue to display, be searchable, and keep their provenance.

## Proposed workflow

### 1. Requesting

Staff choose "handwriting transcription" mode for a work, as they do now. A request is created for the work.

### 2. Planning

First, we check that the work can be transcribed at all: for instance, that it has usable images. If it can't, the request fails right away with an explanation, before anything is sent to Gemini.

Next, the work's pages are divided into **quires** of a fixed size (about 10 pages, to be tuned by experiment). We record exactly which pages each quire covers, so that later reordering or editing of the work's pages can't confuse the record. Each quire after the first also gets the **last page of the previous quire as a context page**.

Context pages are sent as **images**, not as transcripts. So no quire needs to wait for any other quire to finish, and Gemini can decide for itself how much to make of the context.

### 3. The guide

Before transcribing anything, Gemini skims the work, the way a person would leaf through a book before starting on page one. It sees a sample of the pages:
- the first and last few pages, which often hold a title page, table of contents, index or list of correspondents
- pages spread evenly through the rest of the work, up to a fixed maximum

It also sees the work's catalog description. From these, Gemini writes a **guide** to the work:
- the people, places, organizations and things it mentions, with the different spellings found
- abbreviations and the writer's conventions
- the languages, scripts and hands used, and where they change
- an outline of how the work is organized
- short notes connecting all of this to the work's subject, with Gemini's confidence in each

The guide is kept short, since it will be sent with every quire.

Works small enough to fit in a single quire skip this step, since that quire already sees every page.

### 4. Review

The process **pauses** after the guide is written. A staff member reads the guide and makes a simple go/no-go decision:
- **Go** starts transcription.
- **No-go** stops the request before any quires are sent, and nothing further is spent on it. Staff can request a new transcription later.

The guide can't be edited by hand in this first version. For a long book, the pause is a cheap checkpoint before most of the cost is spent. For now it is required; once we trust the guide, it can become optional.

### 5. Transcribing

Each quire is sent to Gemini separately. Each one sends:
- its own pages
- its context page
- the work's description
- the guide
- our transcription instructions

The instructions tell Gemini to use the guide only to help with unclear readings, and always to transcribe **what is actually written**, even where it differs from the guide.

Quires don't depend on each other, so several can run at once, up to a limit we set to respect Gemini's rate limits and our budget. As each quire finishes, its transcripts are saved to its pages and become visible and searchable. Gemini's notes are saved on the quire.

### 6. Finishing, retrying and removing

- **The status of a request follows from the status of its quires:**
  - *failed*, if it failed before any quires were made
  - *in progress*, while the guide or any quire is unfinished
  - *awaiting review*, while the guide waits for approval
  - *stopped*, if staff decided not to go ahead after reading the guide
  - *success*, once every quire has succeeded
  - *partly failed*, if some quires failed (for example, "3 of 48 quires failed")
- **Pages from successful quires keep their transcripts even if other quires fail.** Pages are independent, and a page without a transcript simply shows none.
- **Staff can retry just the failed quires.** They don't need to redo the whole work.
- **Deleting or replacing a transcription still clears the transcripts from every page,** together with the request and its quires, so no page keeps a transcript whose record of origin has gone.

### What we will measure

The trial works of 30 to 100 pages let us compare approaches before building more. Here are some things to look at:
- **The first lines of each quire:** whether the context page is enough to bridge the page break.
- **Consistency of names and abbreviations across quires,** with and without the guide.
- **Gemini's own notes on its work,** which may say directly whether the guide or context helped.
- **Cost and time per page.**

### Deliberately left out of the first version

- **Chains of quires,** where each quire waits for the previous quire's transcript. Context images and the guide may make these unnecessary. If the trial shows otherwise, we can split books into sections that each run as a chain, with the sections running at the same time. The guide's outline of the work could suggest where to divide it.
- **A second pass over the joins between quires** to smooth out page-break errors. This is also a possibility if the trial shows a need.
- **Revising the guide.** If guides turn out to need corrections, staff could write free-text feedback (for example, "the writer's brother is Jehan, not Johann"), and Gemini would rewrite the guide from it. This is safer than editing the guide by hand, because the guide is structured data that's easy to break with a manual edit.
- **Gemini's discounted Batch API,** which is cheaper but slower. Because the quires are independent, it should be easy to add later.

## Summary of changes

### Data

- **Requests get their own database table** instead of living inside the work's metadata. Each work has at most one current request. The request holds:
  - provenance: the Gemini model, the version of our code, and a fingerprint of the source images so we can tell when they've changed
  - the guide, its status, and the staff go/no-go decision (who made it, and when)
  - any error that stopped the request before planning
- **A new table of quires,** belonging to a request. Each quire records:
  - its position
  - the pages it transcribes and its context pages
  - its own status and error
  - Gemini's notes
  - when it ran
  - its own fingerprint, so a stale transcript can be traced to a specific quire
- **Transcripts stay where they are now,** on each page.

### Process

- **The transcription service is reorganized around quires.** Planning, the guide, and transcribing a quire become separate steps, each run as its own background job.
- **The 10-page limit becomes a limit per quire,** not per work. A new and much higher limit per work (initially perhaps 100 pages) guards against accidentally starting a very expensive job.
- **Gemini's instructions get a version for quires** that explains context pages and the guide, and a new set of instructions produces the guide.
- **A limit on how many quire jobs run at once,** probably a dedicated job queue with a fixed number of workers.
- **Status updates no longer rewrite the work's record.** This removes the cause of the search indexing bug and the workarounds we added for it.

### Staff screens

- **The work's admin page shows the request's progress quire by quire.** For example, "12 of 48 quires done" and "3 failed", with each failure's error and Gemini's notes.
- **A review page for the guide,** showing it in readable form, with "go" and "no-go" buttons.
- **A "retry failed quires" action,** alongside the existing "request new transcription" and "delete transcription".

### Public site

- **No changes needed.** The public site already reads transcripts from each page. A partly finished or partly failed transcription shows whichever pages have transcripts.

### Existing transcriptions

- **A one-time migration** moves each existing request out of its work's metadata into the new table. Each becomes a request with a single quire covering all of the work's pages, keeping its notes and provenance. After that, the code only needs to handle one format. We'll check carefully that every transcribed work looks the same before and after.

## Open questions

- **Quire size and context.** Is 10 pages per quire the right size? And is one context page enough?
- **Guide sampling.** How many pages should the guide be based on, and how should they be picked?
- **The guide's audience.** Should staff only see the guide? Could it one day be useful to the public?
- **Large jobs.** Should a work above some size need an explicit go-ahead, or show a cost estimate, before it is requested?
- **Concurrency.** How many quires should run at once, given Gemini's rate limits and our budget?
- **Partly failed requests.** Should a partly failed request be flagged anywhere other than the work's admin page?
