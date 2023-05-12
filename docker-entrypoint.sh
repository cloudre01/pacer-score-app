#!/bin/sh

echo "Flush the manage.py command if any"

while ! python manage.py flush --no-input 2>&1; do
  echo "Flushing django manage command"
  sleep 3
done

echo "Migrate the Database at startup of project"

# Wait for few minute and run db migration
while ! python manage.py migrate  2>&1; do
   echo "Migration is in progress status"
   sleep 3
done

echo "Django docker is fully configured successfully."

exec "$@"