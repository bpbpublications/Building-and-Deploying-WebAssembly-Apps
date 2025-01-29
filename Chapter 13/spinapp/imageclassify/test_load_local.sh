#!/bin/bash
for (( c=1; c<=1; c++ ))
do
    echo $c
    curl -X POST -H "Content-Type: application/octet-stream" --data-binary @lawn.jpg http://localhost:3000/imageclassify &
done