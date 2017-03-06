#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

set_mkinicpio_hooks(){
    if ! ${pxe_boot};then
        msg2 "Removing pxe hooks"
        sed -e 's/miso_pxe_common miso_pxe_http miso_pxe_nbd miso_pxe_nfs //' \
        -e 's/memdisk //' -i $1
    fi
    if ! ${use_overlayfs};then
        msg2 "Setting aufs hook"
        sed -e 's/miso /miso_aufs /' -i $1
    fi
}

prepare_initcpio(){
    msg2 "Copying initcpio ..."
    cp /etc/initcpio/hooks/miso* $1/etc/initcpio/hooks
    cp /etc/initcpio/install/miso* $1/etc/initcpio/install
    cp /etc/initcpio/miso_shutdown $1/etc/initcpio
}

prepare_initramfs(){
    cp $1/mkinitcpio.conf $2/etc/mkinitcpio-${iso_name}.conf
    set_mkinicpio_hooks "$2/etc/mkinitcpio-${iso_name}.conf"
    local _kernver=$(cat $2/usr/lib/modules/*/version)
    if [[ -n ${gpgkey} ]]; then
        su ${OWNER} -c "gpg --export ${gpgkey} >${USERCONFDIR}/gpgkey"
        exec 17<>${USERCONFDIR}/gpgkey
    fi
    MISO_GNUPG_FD=${gpgkey:+17} chroot-run $2 \
        /usr/bin/mkinitcpio -k ${_kernver} \
        -c /etc/mkinitcpio-${iso_name}.conf \
        -g /boot/initramfs.img

    if [[ -n ${gpgkey} ]]; then
        exec 17<&-
    fi
    if [[ -f ${USERCONFDIR}/gpgkey ]]; then
        rm ${USERCONFDIR}/gpgkey
    fi
}

prepare_boot_extras(){
    cp $1/boot/intel-ucode.img $2/intel_ucode.img
    cp $1/usr/share/licenses/intel-ucode/LICENSE $2/intel_ucode.LICENSE
    cp $1/boot/memtest86+/memtest.bin $2/memtest
    cp $1/usr/share/licenses/common/GPL2/license.txt $2/memtest.COPYING
}

# prepare_efiboot_image(){
#     local efi=$1/EFI/miso boot=$2/${iso_name}/boot
#     prepare_dir "${efi}"
#     cp ${boot}/x86_64/vmlinuz ${efi}/vmlinuz.efi
#     cp ${boot}/x86_64/initramfs.img ${efi}/initramfs.img
#     if [[ -f ${boot}/intel_ucode.img ]] ; then
#         cp ${boot}/intel_ucode.img ${efi}/intel_ucode.img
#     fi
# }

vars_to_boot_conf(){
    sed -e "s|@ISO_NAME@|${iso_name}|g" \
        -e "s|@ISO_LABEL@|${iso_label}|g" \
        -e "s|@DIST_NAME@|${dist_name}|g" \
        -e "s|@ARCH@|${target_arch}|g" \
        -e "s|@BOOT_ARGS@||g" \
        -i $1
}

prepare_grub_boot(){
    msg2 "Preparing grub.cfg ..."
    local grub_dir=$1/grub
    mkdir "${grub_dir}" #/{fonts,themes,locale}
    cp /usr/share/manjaro-tools/grub.cfg "${grub_dir}"
    local drv='nonfree' switch="no"
    ${nonfree_mhwd} && switch="yes"
    vars_to_boot_conf ${grub_dir}/grub.cfg #"${drv}" "${switch}"
#     cp -r /usr/lib/grub/x86_64-efi/ "${grub_dir}"
#     cp /usr/share/grub/unicode.pf2 "${grub_dir}/fonts"
}

# prepare_efi_grub(){
#     local efi=$1/EFI/boot grub_dir=$1/boot/grub
#     msg2 "Preparing efi grub ..."
#
#     prepare_dir "${efi}"
#
#
#     cp $2/usr/share/efitools/efi/PreLoader.efi ${efi}/bootx64.efi
#     #cp $2/usr/share/efi-utils/grubx64.efi ${efi}/
#
#
# }

# check_syslinux_select(){
#     local boot=${iso_root}/${iso_name}/boot
#     if [[ ! -f ${boot}/x86_64/vmlinuz ]] ; then
#         msg2 "Configuring syslinux for i686 architecture only ..."
#         sed -e "s/select.cfg/i686_inc.cfg/g" -i "$1/miso.cfg"
#     fi
# }
#
# check_syslinux_nonfree(){
#     msg2 "Configuring syslinux menu ..."
#     sed -e "/LABEL nonfree/,/^$/d" -i "$1/miso_sys_i686.cfg"
#     sed -e "/LABEL nonfree/,/^$/d" -i "$1/miso_sys_x86_64.cfg"
#     sed -e "/nonfree/ d" -i $1/syslinux.msg
# }
#
# prepare_isolinux(){
#     local syslinux=$1/usr/lib/syslinux/bios
#     msg2 "Copying isolinux binaries ..."
#     cp ${syslinux}/{{isolinux,isohdpfx}.bin,ldlinux.c32} $2
#     msg2 "Copying isolinux.cfg ..."
#     cp $1/usr/share/syslinux/isolinux/isolinux.cfg $2
#     vars_to_boot_conf "$2/isolinux.cfg"
# }
#
# prepare_syslinux(){
#     local syslinux=$1/usr/lib/syslinux/bios
#     msg2 "Copying syslinux binaries ..."
#     cp ${syslinux}/{*.c32,lpxelinux.0,memdisk} $2
#     msg2 "Copying syslinux theme ..."
#     syslinux=$1/usr/share/syslinux/theme
#     cp ${syslinux}/* $2
#     for conf in $2/*.cfg; do
#         vars_to_boot_conf "${conf}"
#     done
#     # Check for dual-arch
#     check_syslinux_select "$2"
#     if ! ${nonfree_mhwd};then
#         check_syslinux_nonfree "$2"
#     fi
# }
