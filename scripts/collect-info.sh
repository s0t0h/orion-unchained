#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Print what Orion Unchained needs to support another Acer desktop.
# Read-only: nothing is written anywhere and no serial numbers are printed.
# Run it with sudo so dmidecode and the driver's debugfs file can be read.
#
#   sudo sh scripts/collect-info.sh > report.md

dmi() { cat "/sys/class/dmi/id/$1" 2>/dev/null; }

echo "## Orion Unchained hardware report"
echo
echo '```'
echo "model:    $(dmi sys_vendor) $(dmi product_name)"
echo "board:    $(dmi board_name)"
echo "bios:     $(dmi bios_version) ($(dmi bios_date))"
echo "kernel:   $(uname -r)"
# shellcheck source=/dev/null
echo "distro:   $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
echo "gpu:      $(lspci -nn 2>/dev/null | grep -E 'VGA compatible|3D controller' | sed 's/^[^ ]* //' | head -2 | tr '\n' ' ')"
echo '```'
echo
echo "### SMBIOS type 172 (Acer OEM table)"
echo '```'
if command -v dmidecode >/dev/null 2>&1 && [ "$(id -u)" = 0 ]; then
	dmidecode -u -t 172 | sed -n '/Header and Data/,/^$/p'
else
	echo "(run as root with dmidecode installed)"
fi
echo '```'
echo
echo "### WMI GUIDs"
echo '```'
for guid in /sys/bus/wmi/devices/*; do basename "$guid"; done | sed 's/-[0-9]*$//' | sort -u
echo '```'
echo
echo "### Driver"
echo '```'
if [ -d /sys/module/acer_predator_dt_rgb ]; then
	echo "acer_predator_dt_rgb $(cat /sys/module/acer_predator_dt_rgb/version 2>/dev/null) loaded"
	for dev in /sys/bus/wmi/drivers/acer-predator-dt-rgb/*/; do
		[ -r "$dev/zones" ] || continue
		echo "smbios 172: $(cat "$dev/smbios_version")"
		echo "zones:      $(cat "$dev/zones")"
	done
	if [ -r /sys/kernel/debug/acer_predator_dt_rgb/state ]; then
		echo "firmware read-back:"
		cat /sys/kernel/debug/acer_predator_dt_rgb/state
	fi
else
	echo "not loaded"
fi
dmesg 2>/dev/null | grep -i 'acer-predator-dt-rgb' | tail -5
echo '```'
