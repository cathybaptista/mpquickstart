#!/usr/bin/env bash

set -e

./orch/show_file.sh $0

# Normally, XDEBUG_MODE=debug,develop but develop breaks the Drupal installation.
# https://www.drupal.org/project/drupal/issues/3405976.
if [ -n "$XDEBUG_MODE" ]; then
  export XDEBUG_MODE=debug
fi

drush cr

# If using Postgres, enable the pg_trgm extension which is required before
# Drupal is installed.
if [ -n "$(drush status | grep pgsql 2>/dev/null)" ]; then
  echo 'Postgres is installed, enabling the pg_trgm extension.'
  drush sql:query 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'
fi

if [ -n "$(ls $(drush php:eval "echo realpath(Drupal\Core\Site\Settings::get('config_sync_directory'));")/*.yml 2>/dev/null)" ]; then
  # Find the profile in config.
  PROFILE=$(grep 'profile:' config/sync/core.extension.yml 2>/dev/null | awk '{print $2}')
  # Check if 'grep' found a match
  if [ -z "$PROFILE" ]; then
      # Set default value to 'minimal'
      PROFILE="minimal"
  fi
  echo "Installing a fresh Drupal site from configuration"
  drush si -y --account-pass='admin' --existing-config ${PROFILE}
  # Required if config splits is enabled.
  if drush pm-list --type=module --status=enabled --no-core | grep 'config_split'; then
    drush cr
    drush cim -y
  fi
else
  echo "Installing a fresh Drupal site without configuration"
  drush si -y --account-pass='admin' minimal
fi

# Clear cache after installation
drush cr

./orch/show_file.sh $0 end
