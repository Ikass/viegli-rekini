#!/usr/bin/env bash

# Exit immediately if any command fails
set -o errexit

bundle install
bin/rails assets:precompile
bin/rails assets:clean

# Migrations run here because pre-deploy commands require a paid instance.
# On a paid plan, move db:migrate to the pre-deploy command instead.
bin/rails db:migrate
