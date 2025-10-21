#!/bin/bash

END=$((SECONDS+600))  # Run for 600 seconds (10 minutes)
URL="http://localhost:8080/productpage"

echo "Starting random load on $URL for 10 minutes..."

while [ $SECONDS -lt $END ]; do
  # Generate a random number of concurrent requests between 1 and 10
  CONCURRENCY=$((RANDOM % 15 + 1))

  # Fire concurrent requests in background
  for ((i=1; i<=CONCURRENCY; i++)); do
    curl -s -o /dev/null "$URL" &
  done

  # Random sleep between 0.5 and 3 seconds to simulate variable traffic
  sleep $(awk -v min=0.5 -v max=3 'BEGIN{srand(); print min+rand()*(max-min)}')
done

echo "Load test completed."
