#!/bin/sh
#
# Copyright (c) 2012 Citrix Systems, Inc.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

LOADPOL=/sbin/load_policy
RESTORECON=/sbin/restorecon

[ -x ${LOADPOL} ] && ${LOADPOL} -i
if [ $? -eq 3 ]; then
    echo "load_policy: Policy load failed and system is in \"enforcing mode\" - HALTING!"
    exit 1
fi

[ -x ${RESTORECON} ] && ${RESTORECON} -r /dev
[ -f /boot/system/firstboot -a -x ${RESTORECON} ] && ${RESTORECON} -r /boot/system

echo "Initializing IMA (can be skipped with no_ima boot parameter)."
if ! grep -w securityfs /proc/mounts >/dev/null; then
    if ! mount -t securityfs securityfs /sys/kernel/security; then
        fatal "Could not mount securityfs."
    fi
fi
if [ ! -d /sys/kernel/security/ima ]; then
    echo "No /sys/kernel/security/ima. Cannot proceed without IMA enabled in the kernel."
fi

# Instead of depending on the kernel to load the IMA X.509 certificate,
# use keyctl. This avoids a bug in certain kernels (https://lkml.org/lkml/2015/9/10/492)
# where the loaded key was not checked sufficiently. We use keyctl here because it is
# slightly smaller than evmctl and is needed anyway.
# (see http://sourceforge.net/p/linux-ima/ima-evm-utils/ci/v0.9/tree/README#l349).
for kind in ima evm; do
    key=/etc/keys/x509_$kind.der
    if [ -s $key ]; then
        id=$(grep -w -e "\.$kind" /proc/keys | cut -d ' ' -f1 | head -n 1)
        if [ "$id" ]; then
        id=$(printf "%d" 0x$id)
        fi
        if [ -z "$id" ]; then
        id=`keyctl search @u keyring _$kind 2>/dev/null`
        if [ -z "$id" ]; then
            id=`keyctl newring _$kind @u`
        fi
        fi
        echo "Loading $key into $kind keyring $id"
        keyctl padd asymmetric "" $id <$key
    fi
done

exec "$@"
