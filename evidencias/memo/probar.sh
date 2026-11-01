#!/bin/bash
# Uso: probar.sh <archivo-salida> <n1> <n2> ...  (llama FibonacciMemo una vez por cada n, en orden)
H=https://functionprojectfibonaccisc-d9hkfjadcaerb0cb.eastus2-01.azurewebsites.net
out=$1; shift
for n in "$@"; do
    r=$(curl -s -w '\n%{http_code} %{time_total}' -X POST -H 'Content-Type: application/json' -d "{\"nth\": $n}" $H/api/FibonacciMemo)
    linea=$(echo "$r" | node -e '
        let d = require("fs").readFileSync(0, "utf8").trim().split("\n");
        let [code, t] = d.pop().split(" ");
        let b = JSON.parse(d.join("\n"));
        if (b.answer) b.answer = b.answer.slice(0, 20) + "... (" + b.answer.length + " digitos)";
        console.log(JSON.stringify(b) + " HTTP=" + code + " total=" + t + "s");')
    echo "$(date '+%H:%M:%S') nth=$n -> $linea" | tee -a "$out"
done
