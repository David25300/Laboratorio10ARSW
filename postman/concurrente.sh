#!/bin/bash
# Lanza 10 newman en paralelo; cada uno envia una peticion, asi hay 10 peticiones concurrentes
cd "$(dirname "$0")"
mkdir -p ../evidencias/newman
for i in $(seq 1 10); do
    newman run ARSW_FUNCTIONS_FIBONACCI.postman_collection.json \
        -e "[ARSW_FUNCTIONS_FIBONACCI].postman_environment.json" \
        --reporters cli,json --reporter-json-export ../evidencias/newman/peticion-$i.json \
        > ../evidencias/newman/peticion-$i.txt 2>&1 &
done
wait
grep -h "average response time" ../evidencias/newman/peticion-*.txt
