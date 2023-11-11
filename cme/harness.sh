#!/bin/bash

# Define a timeout duration in seconds
CME_TIMEOUT=60 # Adjust this value as needed

# Function to create output file names
create_output_filenames() {
    local ip_range=$1
    local safe_ip_range=${ip_range//\//-}
    initial_output="${safe_ip_range}-initial-cme.txt"
    cred_output="${safe_ip_range}-cred-cme.txt"
    smb_relay_output="${safe_ip_range}-smb-relay.txt"
}

# Function to clear output files
clear_output_files() {
    > $initial_output
    > $cred_output
    > $smb_relay_output
}

# Function to run SMB relayable hosts scan
run_smb_relay_scan() {
    local ip_range=$1
    echo "Running SMB relayable hosts scan..."
    timeout $CME_TIMEOUT crackmapexec smb $ip_range --gen-relay-list $smb_relay_output
    if [ $? -eq 124 ]; then
        echo "Timeout occurred for SMB relayable hosts scan" | tee -a $smb_relay_output
    fi
}

# Function to run initial scan across all protocols
run_initial_scan() {
    local ip_range=$1
    echo "Running initial scan on all protocols..." | tee -a $initial_output
    for protocol in smb ftp ldap mssql rdp ssh winrm; do
        echo "Scanning with protocol: $protocol" | tee -a $initial_output
        timeout $CME_TIMEOUT crackmapexec $protocol $ip_range | tee -a $initial_output
        if [ $? -eq 124 ]; then
            echo "Timeout occurred for protocol $protocol" | tee -a $initial_output
        fi
        echo "-------------------------------------" | tee -a $initial_output
    done
}

# Function to run credentialed SMB scan
run_cred_scan() {
    local ip_range=$1
    local user=$2
    local pass=$3
    echo "Running credentialed SMB scan..." | tee -a $cred_output
    timeout $CME_TIMEOUT crackmapexec smb $ip_range -u $user -p $pass | tee -a $cred_output
    if [ $? -eq 124 ]; then
        echo "Timeout occurred for SMB scan" | tee -a $cred_output
    fi
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --initial) initial_scan=true ;;
        --user) user="$2"; shift ;;
        --pass) pass="$2"; shift ;;
        --ip-range) ip_range="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Validate IP range
if [ -z "$ip_range" ]; then
    echo "IP range is required."
    exit 1
fi

# Create output file names based on the IP range
create_output_filenames $ip_range

# Clear existing contents of the output files
clear_output_files

# Run SMB relayable hosts scan before other scans
run_smb_relay_scan $ip_range

# Run the appropriate scan based on the flags
if [ "$initial_scan" = true ]; then
    run_initial_scan $ip_range
elif [ -n "$user" ] && [ -n "$pass" ]; then
    run_cred_scan $ip_range $user $pass
else
    echo "Either --initial flag or both --user and --pass are required."
    exit 1
fi
