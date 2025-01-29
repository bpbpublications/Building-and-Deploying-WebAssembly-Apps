#!/bin/bash
curl -H "Host: myhost.com" -X POST -H "Content-Type: application/octet-stream" --data-binary @lawn.jpg http://localhost:8080/imageclassify
