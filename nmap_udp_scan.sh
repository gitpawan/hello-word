#!/bin/bash

# Usage check
if [ $# -lt 2 ]; then
    echo "Usage: $0 <ip_list_file> <max_parallel_scans>"
    echo "Example: $0 ips.txt 4"
    exit 1
fi

ip_file="$1"
max_parallel="$2"

# Validate file
if [ ! -f "$ip_file" ]; then
    echo "File not found: $ip_file"
    exit 1
fi

# Validate max_parallel is a number
if ! [[ "$max_parallel" =~ ^[0-9]+$ ]]; then
    echo "Max parallel scans must be a number."
    exit 1
fi

output_dir="nmap_udp_scan_results"
mkdir -p "$output_dir"

# Function to scan one IP for UDP ports
scan_ip_udp() {
    local ip="$1"
    local output_file="$output_dir/${ip//./_}_udp.txt"
    echo "Starting UDP scan on $ip ..."
    nmap -sU --top-ports 1000 -T4 "$ip" -oN "$output_file"
    echo "Completed UDP scan for $ip. Saved to $output_file"
}

# Limit parallel jobs
current_jobs=0

while IFS= read -r ip; do
    if [[ -n "$ip" ]]; then
        scan_ip_udp "$ip" &
        ((current_jobs++))

        if [ "$current_jobs" -ge "$max_parallel" ]; then
            wait
            current_jobs=0
        fi
    fi
done < "$ip_file"

wait

echo "All UDP scans completed. Results are in: $output_dir"
