#!/bin/bash

TARGET=$1
MODE=$2   # naabu | rustscan

if [ -z "$TARGET" ] || [ -z "$MODE" ]; then
    echo "Usage: $0 <TARGET_IP> <naabu|rustscan>"
    exit 1
fi

PORT_SAMPLE="21,22,25,53,80,110,139,143,443,445,3389,8080,8443"

echo "[*] Target: $TARGET"
echo "[*] Mode: $MODE"

########################################
# NAABU TUNING
########################################
if [ "$MODE" == "naabu" ]; then

    RATE=1000
    MAX_RATE=5000
    MIN_RATE=300

    get_ports() {
        naabu -host $TARGET -p $PORT_SAMPLE -s connect -rate $RATE -retries 2 -timeout 3000 -silent | sort
    }

    echo "[*] Tuning Naabu..."

    for i in {1..5}; do
        echo "[*] Testing rate=$RATE"

        OUT1=$(get_ports)
        sleep 1
        OUT2=$(get_ports)

        if [ "$OUT1" == "$OUT2" ]; then
            echo "[+] Stable → increasing rate"
            RATE=$((RATE + 500))
            [ $RATE -gt $MAX_RATE ] && RATE=$MAX_RATE
        else
            echo "[!] Unstable → decreasing rate"
            RATE=$((RATE - 300))
            [ $RATE -lt $MIN_RATE ] && RATE=$MIN_RATE
        fi

        sleep 2
    done

    echo "[*] Final Naabu rate: $RATE"

    naabu -host $TARGET -p - -s connect -rate $RATE -retries 5 -timeout 5000 -oN naabu_full.txt
    exit 0
fi

########################################
# RUSTSCAN TUNING
########################################
if [ "$MODE" == "rustscan" ]; then

    ULIMIT=2000
    BATCH=1000
    TIMEOUT=3000

    MAX_ULIMIT=8000
    MIN_ULIMIT=500

    get_ports() {
        rustscan -a $TARGET -p $PORT_SAMPLE --ulimit $ULIMIT --no-nmap -b $BATCH -t $TIMEOUT 2>/dev/null | grep "Open" | sort
    }

    echo "[*] Tuning RustScan..."

    for i in {1..5}; do
        echo "[*] Testing ulimit=$ULIMIT batch=$BATCH"

        OUT1=$(get_ports)
        sleep 1
        OUT2=$(get_ports)

        if [ "$OUT1" == "$OUT2" ]; then
            echo "[+] Stable → increasing aggressiveness"
            ULIMIT=$((ULIMIT + 1000))
            BATCH=$((BATCH + 500))
            [ $ULIMIT -gt $MAX_ULIMIT ] && ULIMIT=$MAX_ULIMIT
        else
            echo "[!] Unstable → decreasing aggressiveness"
            ULIMIT=$((ULIMIT - 500))
            BATCH=$((BATCH - 300))
            [ $ULIMIT -lt $MIN_ULIMIT ] && ULIMIT=$MIN_ULIMIT
        fi

        sleep 2
    done

    echo "[*] Final RustScan settings: ulimit=$ULIMIT batch=$BATCH"

    rustscan -a $TARGET -r 1-65535 --ulimit $ULIMIT --no-nmap -b $BATCH -t $TIMEOUT
    exit 0
fi

echo "[!] Invalid mode. Use 'naabu' or 'rustscan'"
exit 1
