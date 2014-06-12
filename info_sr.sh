#! /bin/sh -e

get_cpu()
{
    cat cpuinfo.log | sed -n -re 's/^model name.*: (.*)$/\1/p'
}

get_pci_class()
{
    local class="$1"
    cat lspci-mmnn.log  | grep "\[${class}\]" | sed -re 's/"//g'
}

get_xc_build_info()
{
    local info="$1"

    cat xenclient.conf.log  | sed -n -re "s/^${info} = (.*)$/\1/p"
}

get_txt_measured()
{
    if grep -q 'TXT measured launch: TRUE' txt-stat.log
    then
        echo "true"
    else
        echo "false"
    fi
}

get_wired_mac()
{
    cat ifconfig.log  | grep brbridged | sed -n -re 's/.* HWaddr ([0-9A-F:]*).*/\1/p'
}

get_asset()
{
    f="/home/xc_assets/data/by_mac/`get_wired_mac`/ham"
    [ -f "$f" ] && cat "$f"
}

get_dmi_info()
{
    local table="$1"
    local field="$2"
    sed -n -re "/DMI type ${table},/,/^$/ s/.*${field}: (.*)$/\1/p" dmidecode.log
}

get_bios_info()
{
    get_dmi_info "0" "$1"
}

get_machine_info()
{
    get_dmi_info "1" "$1"
}

get_xenops_physinfo()
{
    cat xenops_physinfo.log | sed -n -re "s/${1} = (.*)$/\1/p"
}

get_vm_node()
{
    local db="$1"
    local field="$2"
    sed -n -re "s|.*\"${field}\": \"(.*)\".*|\1|p" "${db}"
}

display_vm()
{
    local db="$1"
    local format=""

    printf "%s\n" "`get_vm_node "$db" "uuid"`"

    format="    %-20s: %s\n"

    for i in \
        name hvm slot start_on_boot \
        memory amt-pt hibernated \
        gpu \
        pv-addons-installed pv-addons-version portica-installed \
        portica-enabled
    do
        printf "$format" "$i" "`get_vm_node "$db" "$i"`"
    done
    echo ""
}

tmp=`mktemp -d`

tar -C ${tmp} -xf "$1"
cd "${tmp}"/*
tar -xf vms.tar.bz2
tar -xf syslog.tar.bz2

format="%-40s %s\n"
printf "$format" "XenClient build" "`get_xc_build_info 'build'`"
printf "$format" "XenClient build date" "`get_xc_build_info 'build_date'`"
printf "$format" "XenClient build branch" "`get_xc_build_info 'build_branch'`"
printf "$format" "XenClient build tools" "`get_xc_build_info 'tools'`"
printf "$format" "XenClient release" "`get_xc_build_info 'release'`"

echo ""
printf "$format" "Asset" "`get_asset`"
printf "$format" "BIOS Vendor" "`get_bios_info 'Vendor'`"
printf "$format" "BIOS Version" "`get_bios_info 'Version'`"
printf "$format" "BIOS Release Date" "`get_bios_info 'Release Date'`"

echo ""
printf "$format" "Manufacturer" "`get_machine_info 'Manufacturer'`"
printf "$format" "Product" "`get_machine_info 'Product Name'`"
printf "$format" "Serial" "`get_machine_info 'Serial Number'`"
printf "$format" "Wake UP" "`get_machine_info 'Wake-up Type'`"
printf "$format" "SKU" "`get_machine_info 'SKU Number'`"
printf "$format" "UUID" "`get_machine_info 'UUID'`"

echo ""
printf "$format" "CPU" "`get_cpu`"
printf "$format" "CPUs" "`get_xenops_physinfo 'nr_cpus'`"
printf "$format" "RAM" "`get_xenops_physinfo 'total_pages'`"
printf "$format" "GPU" "`get_pci_class 0300`"
printf "$format" "Wireless Card" "`get_pci_class 0280`"
printf "$format" "Wired Card" "`get_pci_class 0200`"
printf "$format" "Wired Mac" "`get_wired_mac`"
printf "$format" "TXT measured" "`get_txt_measured`"

echo ""
for i in *.db
do
    display_vm "$i"
done




cd /tmp
rm -rf "${tmp}"
