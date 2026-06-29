# Claude Code Instructions

## Running rspec

Use `./bin/chruby-exec-rspec` instead of bare `rspec` or the `chruby-exec` pattern. Never run multiple rspec processes in parallel — there is shared state that will conflict.

**IMPORTANT: Never put env vars before the command.** Pass them as the first arguments to the script instead — it handles setting them:

```
# correct
./bin/chruby-exec-rspec TEST_STACK_PROF=1 TEST_STACK_PROF_FORMAT=json spec/foo_spec.rb

# WRONG — interferes with our allow-listing of ./bin/chruby-exec-rspec command in permissions
TEST_STACK_PROF=1 TEST_STACK_PROF_FORMAT=json ./bin/chruby-exec-rspec spec/foo_spec.rb
```

## Running other Ruby commands

Prefix Ruby shell commands (`ruby`, `bundle`, `rake`, etc.) with `chruby-exec $(cat .ruby-version) --`:

```
chruby-exec $(cat .ruby-version) -- bundle exec rake
```
