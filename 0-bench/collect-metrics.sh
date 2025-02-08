#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Usage: $0 <minutes>"
    exit 1
fi

duration=$(( $1 * 60 ))  # Convert minutes to seconds
interval=5  # Collection interval in seconds
log_prefix="collect"

echo "Starting metrics collection at: $(date '+%Y%m%d-%H%M%S')"
echo "Logging data for $1 minutes..."

# Define log files
ps_log="${log_prefix}-ps.log"
net_log="${log_prefix}-net.log"
vm_log="${log_prefix}-vm.log"
io_log="${log_prefix}-disk.log"

# Clear old logs
> "$ps_log"
> "$net_log"
> "$vm_log"
> "$io_log"

end_time=$(( $(date +%s) + duration ))

while [[ $(date +%s) -lt $end_time ]]; do
    timestamp="[$(date '+%Y%m%d-%H%M%S')]"
    
    # Collect process stats
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head | awk -v ts="$timestamp" '{print ts, $0}' >> "$ps_log" &
    
    # Collect network stats
    ifstat -t 1 1 | tail -n +3 | awk -v ts="$timestamp" '{print ts, $0}' >> "$net_log" &
    
    # Collect memory and CPU stats
    vmstat 1 2 | tail -n 1 | awk -v ts="$timestamp" '{print ts, $0}' >> "$vm_log" &
    
    # Collect disk IO stats
    sudo /usr/sbin/iotop -botqqq --iter=1 | awk -v ts="$timestamp" '{print ts, $0}' >> "$io_log" &
    
    sleep $interval
done

echo "Metrics collection ended at: $(date '+%Y%m%d-%H%M%S')"

echo "Summarizing collected data..."

# Compute averages
avg_ps_mem=$(awk '{sum+=$4} END {if (NR>0) print sum/NR; else print 0}' "$ps_log")
avg_ps_cpu=$(awk '{sum+=$5} END {if (NR>0) print sum/NR; else print 0}' "$ps_log")
avg_net=$(awk '{sum_in+=$2; sum_out+=$3} END {if (NR>0) print sum_in/NR, sum_out/NR; else print 0, 0}' "$net_log")
avg_vm=$(awk '{sum+=$15} END {if (NR>0) print sum/NR; else print 0}' "$vm_log")
avg_io=$(awk '{sum+=$1} END {if (NR>0) print sum/NR; else print 0}' "$io_log")

echo "Average Metrics:"
echo "Process Memory Usage: $avg_ps_mem%"
echo "Process CPU Usage: $avg_ps_cpu%"
echo "Network (In/Out KB/s): $avg_net"
echo "CPU Idle Time: $avg_vm%"
echo "Average Disk IO: $avg_io"

echo "Logs saved in $log_prefix-*.log"

