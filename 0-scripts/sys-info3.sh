# Detect virtualization type early
virt=$(systemd-detect-virt)
is_vm=false
[[ "$virt" != "none" ]] && is_vm=true

print_aligned "Virtualization" "$virt"

# BIOS / Hardware Info
if $is_vm; then
    print_aligned "Make/Model" "Unavailable in VM"
    print_aligned "Serial Number" "Unavailable in VM"
    print_aligned "BIOS Version" "Unavailable in VM"
    print_aligned "Motherboard" "Unavailable in VM"
else
    print_aligned "Make/Model" "$(safe_cmd dmidecode -s system-product-name)"
    print_aligned "Serial Number" "$(safe_cmd dmidecode -s system-serial-number)"
    print_aligned "BIOS Version" "$(safe_cmd dmidecode -s bios-version)"
    print_aligned "Motherboard" "$(safe_cmd dmidecode -s baseboard-manufacturer) $(safe_cmd dmidecode -s baseboard-product-name)"
fi

# NUMA (not available in most VMs)
numa=$(lscpu | awk -F: '/NUMA node\(s\)/ { print $2 }' | sed 's/^[ \t]*//')
[[ -z "$numa" || "$numa" == "0" ]] && numa="Unavailable in VM"
print_aligned "NUMA Nodes" "$numa"

# GPU Info
gpu_info=()
while read -r id; do
    [[ -z "$id" ]] && continue
    gpu_info+=("$(lspci -vnn -s "$id" | head -n1 | sed 's/^[ \t]*//')")
done <<< "$(lspci | grep -i 'vga\|3d' | cut -d' ' -f1)"

if (( ${#gpu_info[@]} > 0 )); then
    print_multiline_aligned "Display Card" "${gpu_info[@]}"
else
    print_aligned "Display Card" "Unavailable or Synthetic (VM)"
fi

# Driver detection — allow dxgkrnl etc
drivers=$(lsmod | awk '/nvidia|amdgpu|i915|dxgkrnl/ {print $1}' | sort -u)
if [[ -n "$drivers" ]]; then
    readarray -t driver_arr <<< "$drivers"
    print_multiline_aligned "Display Driver" "${driver_arr[@]}"
else
    print_aligned "Display Driver" "Unavailable or Synthetic (VM)"
fi

