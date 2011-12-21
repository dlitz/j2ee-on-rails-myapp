#!/bin/bash
set -e  # Abort on errors

git describe --tags --always --dirty > VERSION

unset GEM_HOME GEM_PATH RBENV_VERSION
eval "$(rbenv init -)"

JRUBY="jruby -J-Xmx1024m -J-Djava.awt.headless=true"

$JRUBY -S bundle install
$JRUBY -S bundle exec rake db:test:purge db:migrate db:test:prepare test RAILS_ENV=test
$JRUBY -S bundle exec warble war
