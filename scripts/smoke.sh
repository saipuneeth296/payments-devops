#!/usr/bin/env bash
set -u
BASE=${BASE:-http://localhost:8080}
fail=0
check() {
  if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (want $2, got $3)"; fail=1; fi
}
pay() {
  curl -s -o /tmp/out -w '%{http_code}' -X POST "$BASE/pay" \
    -H 'content-type: application/json' -d "$1"
}

check healthz 200 "$(curl -s -o /dev/null -w '%{http_code}' $BASE/healthz)"
check readyz 200 "$(curl -s -o /dev/null -w '%{http_code}' $BASE/readyz)"

check approved-http 200 "$(pay '{"amount":100.50,"currency":"inr","payer":"a","payee":"b","reference":"r1"}')"
check approved-status approved "$(jq -r .status /tmp/out)"
check currency-normalised INR "$(jq -r .currency /tmp/out)"

check declined-http 200 "$(pay '{"amount":1000000.01,"currency":"INR","payer":"a","payee":"b","reference":"r2"}')"
check declined-status declined "$(jq -r .status /tmp/out)"

check zero-amount 422 "$(pay '{"amount":0,"currency":"INR","payer":"a","payee":"b","reference":"r3"}')"
check bad-currency 422 "$(pay '{"amount":1,"currency":"RUPEES","payer":"a","payee":"b","reference":"r4"}')"

exit $fail
