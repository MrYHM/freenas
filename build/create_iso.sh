#!/bin/sh

set -e

# This script creates a bootable LiveCD ISO from a nanobsd image for FreeNAS

main()
{
	export AVATAR_ROOT=$(realpath "$(dirname "$0")/..")
	. "$AVATAR_ROOT/build/nano_env"
	. "$AVATAR_ROOT/build/functions.sh"

	requires_root

	# Keep in sync with os-base and nano_env.
	IMGFILE="${NANO_OBJ}/$NANO_IMGNAME.img.xz"
	TEMP_IMGFILE="${NANO_OBJ}/_.imgfile" # Scratch file for image

	INSTALLER_FILES="$AVATAR_ROOT/nanobsd/Installer"
	AVATAR_CONF="$NANO_OBJ/_.w/etc/avatar.conf"

	# Various mount points needed to build the CD, adjust to taste
	ISODIR="${NANO_OBJ}/_.isodir" # Directory ISO is rolled from
	INSTALLUFSDIR="${NANO_OBJ}/_.instufs" # Scratch mountpoint where the image will be dissected

	OUTPUT="${NANO_OBJ}/$NANO_NAME.iso" # Output file of mkisofs

	MKISOFS_CMD="/usr/local/bin/mkisofs -R -l -ldots -allow-lowercase \
			 -allow-multidot -hide boot.catalog -o ${OUTPUT} -no-emul-boot \
			 -b boot/cdboot ${ISODIR}"

	if ! command -v mkisofs >/dev/null 2>&1; then
		make -C /usr/ports/sysutils/cdrtools clean install
	fi

	if [ ! -f "${IMGFILE}" ]; then
		error "Can't find image file (${IMGFILE}) for ${REVISION}, punting"
	fi

	IMG_SIZE=$(xz --list --robot "$IMGFILE" | awk '/^totals/ { print $5 }')
	if [ "${IMG_SIZE:-0}" -le 0 ]
	then
		error "Image file (${IMGFILE}) is invalid/empty"
	fi

	cleanup

	cd "$AVATAR_ROOT"


	mkdir -p ${ISODIR}/data
	mkdir -p ${ISODIR}/dev
	mkdir -p ${ISODIR}/.mount
	mkdir -p ${ISODIR}/mnt
	mkdir -p ${ISODIR}/tmp

	# Create a quick and dirty nano image from the world tree
	mkdir -p ${INSTALLUFSDIR}
	tar -cf - -C ${NANO_OBJ}/_.w --exclude local . | tar -xf - -C ${INSTALLUFSDIR}

	# copy /rescue and /boot from the image to the iso
	tar -cf - -C ${INSTALLUFSDIR} boot --exclude boot/kernel-debug | tar -xf - -C ${ISODIR}
	ln -f $IMGFILE $ISODIR/$NANO_LABEL-$NANO_ARCH_HUMANIZED.img.xz

	(cd build/pc-sysinstall && make install DESTDIR=${INSTALLUFSDIR} NO_MAN=t)
	rm -rf ${INSTALLUFSDIR}/usr/local
	rm -rf ${INSTALLUFSDIR}/usr/include
	rm -f ${INSTALLUFSDIR}/bin/* ${INSTALLUFSDIR}/sbin/*
	rm -f ${INSTALLUFSDIR}/usr/bin/* ${INSTALLUFSDIR}/usr/sbin/*


	cp -p ${AVATAR_ROOT}/build/files/install.sh ${INSTALLUFSDIR}/etc
	cp -p ${AVATAR_ROOT}/build/files/rc ${INSTALLUFSDIR}/etc

	cp "$AVATAR_CONF" ${INSTALLUFSDIR}/etc/
	mkdir -p ${INSTALLUFSDIR}/usr/local/
	tar -cf - -C${INSTALLER_FILES} --exclude .svn . | tar -xpf - -C ${INSTALLUFSDIR}/usr/local/

	mkdir -p ${INSTALLUFSDIR}/.mount
	mkdir -p ${INSTALLUFSDIR}/cdrom
	mkdir -p ${INSTALLUFSDIR}/conf/default/etc
	mkdir -p ${INSTALLUFSDIR}/conf/default/tmp
	mkdir -p ${INSTALLUFSDIR}/conf/default/var
	mkdir -p ${INSTALLUFSDIR}/tank

	mkdir -p ${INSTALLUFSDIR}/usr/local/pre-install

    echo "IMG_SIZE=\"${IMG_SIZE}\"" > \
        ${INSTALLUFSDIR}/etc/avatar_img_size.conf
    cp -p ${AVATAR_ROOT}/build/files/0005.verify_media_size.sh \
        "${INSTALLUFSDIR}/usr/local/pre-install/0005.verify_media_size.sh"

	# XXX: tied too much to the host system to be of value in the
	# installer code.
	rm -f "$INSTALLUFSDIR/etc/rc.conf.local"
	rm -f $INSTALLUFSDIR/etc/fstab
	rm -f $INSTALLUFSDIR/conf/default/etc/remount

	cp -p ${NANO_OBJ}/_.w/bin/cat ${INSTALLUFSDIR}/bin/cat
	cp -p ${NANO_OBJ}/_.w/bin/chmod ${INSTALLUFSDIR}/bin/chmod
	cp -p ${NANO_OBJ}/_.w/bin/mv ${INSTALLUFSDIR}/bin/mv
	cp -p ${NANO_OBJ}/_.w/bin/rm ${INSTALLUFSDIR}/bin/rm
	cp -p ${NANO_OBJ}/_.w/sbin/ifconfig ${INSTALLUFSDIR}/sbin/ifconfig
	cp -p ${NANO_OBJ}/_.w/sbin/mdconfig ${INSTALLUFSDIR}/sbin/mdconfig
	cp -p ${NANO_OBJ}/_.w/sbin/mdmfs ${INSTALLUFSDIR}/sbin/mdmfs
	cp -p ${NANO_OBJ}/_.w/sbin/sysctl ${INSTALLUFSDIR}/sbin/sysctl
	cp -p ${NANO_OBJ}/_.w/bin/sh ${INSTALLUFSDIR}/bin/sh
	cp -p ${NANO_OBJ}/_.w/sbin/gmirror ${INSTALLUFSDIR}/sbin/gmirror
	cp -p ${NANO_OBJ}/_.w/sbin/graid ${INSTALLUFSDIR}/sbin/graid
	cp -p ${NANO_OBJ}/_.w/sbin/mount ${INSTALLUFSDIR}/sbin/mount
	cp -p ${NANO_OBJ}/_.w/sbin/mount_cd9660 ${INSTALLUFSDIR}/sbin/mount_cd9660
	cp -p ${NANO_OBJ}/_.w/sbin/mount_msdosfs ${INSTALLUFSDIR}/sbin/mount_msdosfs
	cp -p ${NANO_OBJ}/_.w/sbin/mount_nfs ${INSTALLUFSDIR}/sbin/mount_nfs
	cp -p ${NANO_OBJ}/_.w/sbin/mount_nullfs ${INSTALLUFSDIR}/sbin/mount_nullfs
	cp -p ${NANO_OBJ}/_.w/sbin/mount_udf ${INSTALLUFSDIR}/sbin/mount_udf
	cp -p ${NANO_OBJ}/_.w/sbin/mount_unionfs ${INSTALLUFSDIR}/sbin/mount_unionfs
	cp -p ${NANO_OBJ}/_.w/sbin/newfs ${INSTALLUFSDIR}/sbin/newfs
	cp -p ${NANO_OBJ}/_.w/sbin/zfs ${INSTALLUFSDIR}/sbin/zfs
	cp -p ${NANO_OBJ}/_.w/sbin/zpool ${INSTALLUFSDIR}/sbin/zpool
	cp -p ${NANO_OBJ}/_.w/usr/bin/awk ${INSTALLUFSDIR}/usr/bin/awk
	cp -p ${NANO_OBJ}/_.w/usr/bin/dialog ${INSTALLUFSDIR}/usr/bin/dialog
	cp -p ${NANO_OBJ}/_.w/usr/bin/grep ${INSTALLUFSDIR}/usr/bin/grep
	cp -p ${NANO_OBJ}/_.w/usr/bin/sed ${INSTALLUFSDIR}/usr/bin/sed
	cp -p ${NANO_OBJ}/_.w/usr/sbin/chown ${INSTALLUFSDIR}/usr/sbin/chown

	# The presence of /etc/diskless will trigger /etc/rc to run /etc/rc.initdiskless.
	touch ${INSTALLUFSDIR}/etc/diskless

	# Copy /etc to /conf/default/etc and /var to /conf/default/var.
	# The /etc/rc.initdiskless script will create memory file systems and copy these directories
	# into those memory file systems.
	tar -c -f - -C ${INSTALLUFSDIR}/etc . | tar -x -p -f - -C ${INSTALLUFSDIR}/conf/default/etc
	tar -c -f - -C ${INSTALLUFSDIR}/var . | tar -x -p -f - -C ${INSTALLUFSDIR}/conf/default/var

	# Compress what's left of the image after mangling it
	makefs -b 10%  ${TEMP_IMGFILE} ${INSTALLUFSDIR}
	mkuzip -o ${ISODIR}/data/base.ufs.uzip ${TEMP_IMGFILE}

	cp -p ${AVATAR_ROOT}/build/files/loader.conf.cdrom ${ISODIR}/boot/loader.conf
	cp -p ${AVATAR_ROOT}/build/files/mount.conf.cdrom ${ISODIR}/.mount.conf

	eval ${MKISOFS_CMD}
	echo "Created ${OUTPUT}"
}

cleanup()
{
	# Clean up directories used to create the liveCD
	rm -Rf "$ISODIR" "$INSTALLUFSDIR"
}

main
