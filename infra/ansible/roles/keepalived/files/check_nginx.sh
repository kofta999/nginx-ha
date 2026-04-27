#!/bin/bash

# 1. Check if Nginx process is running
if ! pgrep -x "nginx" > /dev/null; then
    exit 1
fi

# 2. Check if the /health endpoint returns a 200 status code
# --silent: hide progress bar
# --output: discard the body
# --write-out: extract only the HTTP status code
# --max-time: don't wait forever
# Note: -k is used as nginx is exposed only on HTTPS, with a self signed certificate
HTTP_STATUS=$(curl -k --silent --output /dev/null --write-out "%{http_code}" --max-time 2 https://localhost/health/)

if [ "$HTTP_STATUS" -eq 200 ]; then
    exit 0
else
    exit 1
fi
