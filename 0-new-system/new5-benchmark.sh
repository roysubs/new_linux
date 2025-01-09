#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script requires sudo privileges to perform certain tests."
    exit 1
fi

ENV_DESC="$1"
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
REPORT_PATH="$USER_HOME/benchmark_${ENV_DESC}_${TIMESTAMP}.txt"
DEPENDENCY_LOG="$USER_HOME/benchmark_install_log_${TIMESTAMP}.txt"

# Check for input argument (environment description)
if [ -z "$1" ]; then
    echo "Please provide an environment description as an argument (e.g., microserver_hdd)."
    echo "Resultant output file is: $USER_HOME/benchmark_microserver_hdd_<timestamp>.txt"
    exit 1
fi

# Install dependencies if they are not installed
echo -e "\nChecking for required dependencies..."
for pkg in fio sysbench hdparm; do
    if ! dpkg-query -W -f='${Package}\n' $pkg &>/dev/null; then
        echo "Installing $pkg..."
        sudo apt-get install -y $pkg >> "$DEPENDENCY_LOG" 2>&1
        if ! dpkg-query -W -f='${Package}\n' $pkg &>/dev/null; then
            echo "Failed to install $pkg. Exiting."
            exit 1
        fi
    else
        echo "$pkg is already installed."
    fi
done
echo ""

echo "" > "$REPORT_PATH"
echo "Performance Benchmark Report" | sudo tee -a "$REPORT_PATH"
echo "Generated at: $(date)" | sudo tee -a "$REPORT_PATH"
echo "-----------------------------------" | sudo tee -a "$REPORT_PATH"

# Start timing the benchmark section
BENCHMARK_START=$(date +%s)

# Disk Benchmark
echo -e "\nfio Disk Benchmark Results:" >> "$REPORT_PATH"

function format_number {
    echo $1 | awk '{printf "%\047d", $1}'
}

run_fio() {
    local block_size=$1
    local file_size=$2
    local test_type=$3  #  test type (randread or randwrite)

    # Construct fio command based on test type
    echo -e "fio: $(date)\nfio --name=$test_type --ioengine=sync --rw=$test_type --bs=$block_size --numjobs=1 --size=$file_size --runtime=10s --time_based --output-format=terse"
    
    # Run the fio command and capture output
    fio_output=$(fio --name=$test_type --ioengine=sync --rw=$test_type --bs=$block_size --numjobs=1 --size=$file_size --runtime=10s --time_based --output-format=terse 2>&1)
    
    awk -F';' '{print "Throughput (Bytes): " $6; print "IOPS: " $7; print "Average Latency (us): " $8; print "99th Percentile Latency (us): " $9; print "CPU Utilization (%): " $50}'
    # Extract bandwidth (BW) and IOPS from fio output
    bw=$(echo "$fio_output" | awk -F ';' '{print $48}')
    iops=$(echo "$fio_output" | awk -F ';' '{print $49}')
    
    # Format and print results to the report
    bw_formatted=$(format_number "$bw")
    iops_formatted=$(format_number "$iops")

    # echo "$fio_out" | awk -F';' '{
    #     # Throughput in bytes to human-readable format
    #     throughput=$6
    #     if (throughput >= 1024^3) {
    #         throughput_hr = throughput / 1024^3 " GB"
    #     } else if (throughput >= 1024^2) {
    #         throughput_hr = throughput / 1024^2 " MB"
    #     } else if (throughput >= 1024) {
    #         throughput_hr = throughput / 1024 " KB"
    #     } else {
    #         throughput_hr = throughput " Bytes"
    #     }
    # 
    #     # Print metrics
    #     print "Throughput: " throughput_hr
    #     print "IOPS: " $7
    #     print "Average Latency (us): " $8
    #     print "99th Percentile Latency (us): " $9
    #     print "CPU Utilization (%): " $50
    # }'

    
    printf "\n%-12s%-7s%-12s%-9s%-4s%-12s%-15s%-16s" "Block size" "$block_size" "File size" "$file_size" "=>" "Bandwidth" "$(format_number "$bw") KB/s" "and $iops_formatted IOPS" >> "$REPORT_PATH"
    
    # Clean up test files after the test
    rm -f $test_type.*
}

echo "Run fio randread tests"
for block_size in 4k 64k 512k; do
    for size in 1M 10M 100M; do
        run_fio $block_size $size randread   # Random read test
        echo -e "\n"
    done
done

echo "Run fio randwrite tests"
for block_size in 4k 64k 512k; do
    for size in 1M 10M 100M; do
        run_fio $block_size $size randwrite  # Random write test
        echo -e "\n"
    done
done

# for block_size in 4k 64k 512k 1m; do
#     run_fio $block_size 1M
#     echo -e "\n"
#     # run_fio $block_size 32M
#     # echo -e "\n"
#     # run_fio $block_size 256M
#     # echo -e "\n"
#     # run_fio $block_size 1G
# done

### convert_to_bytes() {
###     local size_str=$1
###     local size_val=${size_str%[kmgKMG]} # Remove the unit (k/m/g/K/M/G) to extract the numeric part
###     local size_unit=${size_str: -1} # Extract the last character for the unit (assume a single character, won't work for kb/mb etc)
### 
###     # Check if size_val is a valid number
###     if ! [[ $size_val =~ ^[0-9]+$ ]]; then
###         echo "Error: Invalid size value '$size_str'" >&2
###         return 1
###     fi
### 
###     # Convert to bytes based on the unit
###     case $size_unit in
###         k|K) echo $((size_val * 1024)) ;;
###         m|M) echo $((size_val * 1024 * 1024)) ;;
###         g|G) echo $((size_val * 1024 * 1024 * 1024)) ;;
###         *) echo "$size_val" ;; # Default to no conversion for unrecognized units
###     esac
### }
### 
### #convert_to_bytes() {
### #    local size=$1
### #    local unit="${size: -1}"  # Get the last character (unit)
### #    local number="${size%${unit}}"  # Get the number part
### #    case "$unit" in
### #        k|K) echo $((number * 1024)) ;;
### #        m|M) echo $((number * 1024 * 1024)) ;;
### #        g|G) echo $((number * 1024 * 1024 * 1024)) ;;
### #        t|T) echo $((number * 1024 * 1024 * 1024 * 1024)) ;;
### #        *) echo $number ;;  # Default to bytes if no unit
### #    esac
### #}
### 
### run_dd() {
###     local file_size=$1
###     local block_size=$2
###     local output_file="${USER_HOME}/dd_${file_size}_$(date +%H-%M-%S)"
###     
###     block_size_bytes=$(convert_to_bytes "$block_size")
###     file_size_bytes=$(convert_to_bytes "$file_size")
###     
###     echo -e "\nRunning dd benchmark for block size $block_size and file size $file_size" >> "$REPORT_PATH"
###     echo -e "$(date)\ndd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes)) oflag=direct"
###     
###     # Run dd with direct I/O
###     echo "Running: dd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes)) oflag=direct"
###     dd_output_raw=$(dd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes)) oflag=direct 2>&1)
###     last_line=$(echo "$dd_output_raw" | tail -n 1)
###     dd_size=$(echo "$last_line" | awk '{print $3,$4}' | sed 's/[(),]//g')
###     dd_speed=$(echo "$last_line" | awk '{print $(NF-1), $NF}')
###     echo -e "Block size (bytes) $block_size_bytes, File size (bytes) $file_size_bytes, Count (num blocks to write) $((file_size_bytes / block_size_bytes))"
###     echo -e "dd size: $dd_size" >> "$REPORT_PATH"
###     echo -e "dd raw speed: $dd_speed" >> "$REPORT_PATH"
###     
###     # Run dd with cached I/O (no oflag=direct)
###     echo "Running: dd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes))"
###     dd_output_cached=$(dd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes)) 2>&1)
###     last_line=$(echo "$dd_output_cached" | tail -n 1)
###     dd_size=$(echo "$last_line" | awk '{print $3,$4}' | sed 's/[(),]//g')
###     dd_speed=$(echo "$last_line" | awk '{print $(NF-1), $NF}')
###     echo -e "Block size (bytes) $block_size_bytes, File size (bytes) $file_size_bytes, Count (num blocks to write) $((file_size_bytes / block_size_bytes))"
###     echo -e "dd size: $dd_size" >> "$REPORT_PATH"
###     echo -e "dd raw speed: $dd_speed" >> "$REPORT_PATH"
### 
###     # Clean up after test (optional)
###     # rm -f "$output_file"
### }
### 
### echo -e "\nDD Benchmark Report - $(date)" >> "$REPORT_PATH"
### 
### # Test combinations of file and block sizes
### for size in 1M 10M 100M; do
###     for block_size in 4k 64kk; do
###         run_dd "$size" "$block_size"
###     done
### done


# run_dd() {
#     local file_size=$1
#     local block_size=$2
#     local output_file="${USER_HOME}/dd_${file_size}_$(date +%s)"
#     block_size_bytes=$(convert_to_bytes "$block_size")
#     file_size_bytes=$(convert_to_bytes "$file_size")
#     echo -e "\nRunning dd benchmark for block size $block_size and file size $file_size" >> "$REPORT_PATH"
#     echo -e "$(date)\ndd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes)) oflag=direct status=progress"
#     # Note that $((file_size_bytes / block_size_bytes)) will always round down to the nearest integer (will not have decimal places)
#     dd_output_raw=$(dd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes)) oflag=direct status=progress 2>&1)
#     dd_output_cached=$(dd if=/dev/zero of=$output_file bs=$block_size count=$((file_size_bytes / block_size_bytes)) status=progress 2>&1)
#     echo -e "DEBUG: RAW    => $dd_output_raw"
#     echo -e "DEBUG: CACHED => $dd_output_cached"
#     # Show the raw output
#     dd_size=$(echo "$dd_output_raw" | grep -oP '\d+ kB' | head -n 1)
#     dd_speed=$(echo "$dd_output_raw" | grep -oP '\d+ kB/s')
#     echo -e "Block size (btyes) $block_size_bytes, File size (btyes) $file_size_bytes, Count (num blocks to write) $((file_size_bytes / block_size_bytes))"
#     echo -e "dd raw $dd_size file created; speed was $dd_speed" >> "$REPORT_PATH"
#     # Show the cached output
#     dd_size=$(echo "$dd_output_cached" | grep -oP '\d+ kB' | head -n 1)
#     dd_speed=$(echo "$dd_output_cached" | grep -oP '\d+ kB/s')
#     echo -e "Block size (btyes) $block_size_bytes, File size (btyes) $file_size_bytes, Count (num blocks to write) $((file_size_bytes / block_size_bytes))"
#     echo -e "dd cached $dd_size file created; speed was $dd_speed" >> "$REPORT_PATH"
#  
#     # echo -e "\n----- End of Test for block size $block_size and file size $file_size -----" >> "$REPORT_PATH"
# 
#     # Clean up after test
#     # rm -f "$output_file"
# }
# 
# echo -e "\nDD Benchmark Report - $(date)" >> "$REPORT_PATH"
# 
# # Test combinations of file and block sizes
# for size in 1M 16M 64M; do
#     for block_size in 4k 8k; do
#         run_dd "$size" "$block_size"
#     done
# done

# Using hdparm to measure sequential read speed
echo -e "\nDisk Benchmark (HDParm - Sequential Read Speed):" >> "$REPORT_PATH"
hdparm_output=$(hdparm -Tt /dev/sda 2>&1)
echo "$hdparm_output" >> "$REPORT_PATH"

# CPU Benchmark
echo -e "\nCPU Benchmark Results:" >> "$REPORT_PATH"
sysbench_output=$(sysbench cpu --time=10 run 2>&1)
echo "$sysbench_output"  # Debugging output for raw data
total_time=$(echo "$sysbench_output" | grep "total time" | awk '{print $3}')
# avg_event_time=$(echo "$sysbench_output" | grep "execution time (avg)" | awk '{print $4}')
# avg_event_time=$(echo "$sysbench_output" | grep "avg" | awk '{print $2}')
avg_event_time=$(echo "$sysbench_output" | grep "avg:" | awk '{for(i=1;i<=NF;i++) if ($i ~ /avg:/) print $(i+1)}')
printf "  Total Time:   %s sec\n" "$total_time" >> "$REPORT_PATH"
printf "  Avg Time:     %s ms\n" "$avg_event_time" >> "$REPORT_PATH"

# RAM Benchmark
echo -e "\nRAM Benchmark Results:" >> "$REPORT_PATH"
sysbench_memory_output=$(sysbench memory --memory-block-size=1M --memory-total-size=2G run 2>&1)
echo "$sysbench_memory_output"  # Debugging output for raw data
transferred=$(echo "$sysbench_memory_output" | grep "transferred" | awk '{print $1 " " $2}')
# Extract total time (in seconds) from sysbench output
ram_total_time=$(echo "$sysbench_memory_output" | grep "total time" | awk '{print $3}' | sed 's/s//')
# Extract total memory transferred (in MiB)
ram_transferred=$(echo "$sysbench_memory_output" | grep "transferred" | awk '{print $1}')
# Calculate throughput (Transferred / Time)
throughput=$(echo "scale=2; $ram_transferred / $ram_total_time" | bc)
# throughput=$(echo "$sysbench_memory_output" | grep "transferred" | awk '{print $5 " " $6}')
printf "  Transferred:  %s\n" "$transferred" >> "$REPORT_PATH"
printf "  Throughput:   %s MiB/sec\n" "$throughput" >> "$REPORT_PATH"

# End timing
BENCHMARK_END=$(date +%s)
BENCHMARK_DURATION=$((BENCHMARK_END - BENCHMARK_START))
echo -e "\nBenchmark completed in $BENCHMARK_DURATION seconds." >> "$REPORT_PATH"

# Display report contents to console
cat "$REPORT_PATH"

# Final message
echo -e "\nReport saved at $REPORT_PATH"

# Notes
echo -e "\nCurrent block size is $(sudo blockdev --getbsz /dev/sda1)"
echo -e "\n4 KB (4096 bytes) is the default for many Linux filesystems, including ext4."
echo -e "Many modern storage devices, such as SSDs and HDDs, are optimized for 4 KB block sizes."
echo -e "Balance between performance and storage efficiency for various types of workloads."
echo -e "Different block sizes, e.g., 64 KB, might be used if a volume contains a database that is optimised for 64 KB blocks."
echo -e ""
echo -e "Filesystem | Default | Small Volumes    | Medium Volumes | Large Volumes"
echo -e "-----------|---------|------------------|----------------|-------------------------"
echo -e "ext4       | 4 KB    | 1-4 KB           | 4 KB           | 4-64 KB (rare)"
echo -e "Btrfs      | 4 KB    | Fixed at 4 KB    | Fixed at 4 KB  | Fixed at 4 KB"
echo -e "ZFS        | 128 KB  | Tunable          | Tunable        | Tunable (512 B to 1 MB+)"
echo -e "ReiserFS   | 4 KB    | Fixed at 4 KB    | Fixed at 4 KB  | Fixed at 4 KB"
echo -e "XFS        | 4 KB    | Fixed at 4 KB    | Fixed at 4 KB  | Tunable (up to 64 KB)"
echo -e "NTFS       | 4 KB    | 512 bytes        | 4-16 KB        | 32-64 KB (large volumes)"
echo -e "exFAT      | 4 KB    | 512 bytes        | 4-16 KB        | 32 KB+"
echo -e "FAT32      | 4 KB    | 512 bytes        | 8-16 KB        | 32 KB (max practical)"
echo -e "FAT16      | 2 KB    | 512 bytes        | 8-32 KB        | 32 KB"
echo -e "APFS       | 4 KB    | Fixed at 4 KB    | Fixed at 4 KB  | Fixed at 4 KB"
echo -e "HFS+       | 4 KB    | 512 bytes        | 4 KB           | 4-32 KB"
echo -e ""

# End notification (5 beeps)
for i in {1..5}; do echo -e "\a"; sleep 1.5; done
