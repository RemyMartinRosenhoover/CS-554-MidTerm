#!/usr/bin/env bash
set -euo pipefail

hosts=(archive.ubuntu.com registry-1.docker.io auth.docker.io ghcr.io raw.githubusercontent.com github.com pkgs.k8s.io)
public_issuers='Sectigo|Amazon|DigiCert|Let.s Encrypt|Google Trust Services|GlobalSign'
result=0
for host in "${hosts[@]}"; do
    printf '\n$ openssl s_client -connect %s:443 -servername %s -verify_return_error -verify_hostname %s\n' "$host" "$host" "$host"
    status=0
    capture=$(timeout 30 openssl s_client -connect "${host}:443" -servername "$host" -verify_return_error -verify_hostname "$host" </dev/null 2>&1) || status=$?
    if [[ "$capture" != *'-----BEGIN CERTIFICATE-----'* ]]; then
        printf '%s\n' "$capture"
        printf 'RESULT: no certificate; TLS probe blocked (exit %s).\n' "$status"
        result=1
        continue
    fi
    details=$(printf '%s\n' "$capture" | openssl x509 -noout -subject -issuer -dates)
    printf '%s\n' "$details"
    printf '%s\n' "$capture" | sed -n '/Verification error:/p; /Verify return code:/p'
    issuer=$(printf '%s\n' "$details" | sed -n 's/^issuer=//p')
    if ! printf '%s\n' "$issuer" | grep -Eq "$public_issuers"; then
        printf 'RESULT: non-public/unknown issuer; STOP before provisioning or image pulls.\n'
        result=2
    elif (( status != 0 )); then
        printf 'RESULT: public issuer but validation failed; STOP (exit %s).\n' "$status"
        if (( result == 0 )); then result=1; fi
    else
        printf 'RESULT: public issuer and certificate validation succeeded.\n'
    fi
done
exit "$result"
