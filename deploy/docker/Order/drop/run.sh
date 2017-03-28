#!/bin/bash

while ! curl http://db:27017/
do
  echo "$(date) - still trying"
  sleep 1
done
echo "$(date) - connected successfully"

java -jar ordering-*.jar
