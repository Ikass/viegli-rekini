# frozen_string_literal: true

# Store timestamps as timestamptz (timestamp with time zone) in PostgreSQL.
# Without this, Rails uses plain timestamp and timezone handling becomes
# ambiguous — important for anything with due dates or created_at comparisons.
#
# Wrapped in a defined? guard because db:create runs before a connection
# exists, so the adapter constant isn't loaded yet at that point.
if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz
end
