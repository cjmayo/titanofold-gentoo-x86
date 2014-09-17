# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/app-backup/bacula/bacula-7.0.4.ebuild,v 1.1 2014/06/21 10:01:19 tomjbe Exp $

EAPI="5"

inherit eutils multilib qt4-r2 systemd user

MY_PV=${PV/_beta/-b}
MY_P=${PN}-${MY_PV}

DESCRIPTION="Featureful client/server network backup suite"
HOMEPAGE="http://www.bacula.org/"
SRC_URI="mirror://sourceforge/bacula/${MY_P}.tar.gz"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~ppc ~sparc ~x86"
IUSE="acl bacula-clientonly bacula-nodir bacula-nosd examples ipv6 logwatch mysql postgres qt4 readline +sqlite3 ssl static tcpd vim-syntax X"

DEPEND="
	dev-libs/gmp
	!bacula-clientonly? (
		postgres? ( dev-db/postgresql-base[threads] )
		mysql? ( virtual/mysql )
		sqlite3? ( dev-db/sqlite:3 )
		!bacula-nodir? ( virtual/mta )
	)
	qt4? (
		dev-qt/qtsvg:4
		x11-libs/qwt:5
	)
	logwatch? ( sys-apps/logwatch )
	tcpd? ( >=sys-apps/tcp-wrappers-7.6 )
	readline? ( >=sys-libs/readline-4.1 )
	static? (
		acl? ( virtual/acl[static-libs] )
		sys-libs/zlib[static-libs]
		dev-libs/lzo[static-libs]
		sys-libs/ncurses[static-libs]
		ssl? ( dev-libs/openssl[static-libs] )
	)
	!static? (
		acl? ( virtual/acl )
		sys-libs/zlib
		dev-libs/lzo
		sys-libs/ncurses
		ssl? ( dev-libs/openssl )
	)"
RDEPEND="${DEPEND}
	!bacula-clientonly? (
		!bacula-nosd? (
			sys-block/mtx
			app-arch/mt-st
		)
	)
	vim-syntax? ( || ( app-editors/vim app-editors/gvim ) )"

REQUIRED_USE="|| ( ^^ ( mysql postgres sqlite3 ) bacula-clientonly )
				static? ( bacula-clientonly )"

S=${WORKDIR}/${MY_P}

pkg_setup() {
	#XOR and !bacula-clientonly controlled by REQUIRED_USE
	use mysql && export mydbtype="mysql"
	use postgres && export mydbtype="postgresql"
	use sqlite3 && export mydbtype="sqlite3"

	# create the daemon group and user
	if [ -z "$(egetent group bacula 2>/dev/null)" ]; then
		enewgroup bacula
		einfo
		einfo "The group 'bacula' has been created. Any users you add to this"
		einfo "group have access to files created by the daemons."
		einfo
	fi

	if use bacula-clientonly && use static && use qt4; then
		ewarn
		ewarn "Building statically linked 'bat' is not supported. Ignorig 'qt4' useflag."
		ewarn
	fi

	if ! use bacula-clientonly; then
		if [ -z "$(egetent passwd bacula 2>/dev/null)" ]; then
			enewuser bacula -1 -1 /var/lib/bacula bacula,disk,tape,cdrom,cdrw
			einfo
			einfo "The user 'bacula' has been created.  Please see the bacula manual"
			einfo "for information about running bacula as a non-root user."
			einfo
		fi
	fi
}

src_prepare() {
	# adjusts default configuration files for several binaries
	# to /etc/bacula/<config> instead of ./<config>
	pushd src >&/dev/null || die
	for f in console/console.c dird/dird.c filed/filed.c \
		stored/bcopy.c stored/bextract.c stored/bls.c \
		stored/bscan.c stored/btape.c stored/stored.c \
		qt-console/main.cpp; do
		sed -i -e 's|^\(#define CONFIG_FILE "\)|\1/etc/bacula/|g' "${f}" \
			|| die "sed on ${f} failed"
	done
	popd >&/dev/null || die

	# bug 466688 drop deprecated categories from Desktop file
	sed -i -e 's/Application;//' scripts/bat.desktop.in || die

	# bug 466690 Use CXXFLAGS instead of CFLAGS
	sed -i -e 's/@CFLAGS@/@CXXFLAGS@/' autoconf/Make.common.in || die

	# drop automatic install of unneeded documentation (for bug 356499)
	epatch "${FILESDIR}"/5.2.3/${PN}-5.2.3-doc.patch

	# bug #310087
	epatch "${FILESDIR}"/5.2.3/${PN}-5.2.3-as-needed.patch

	# bug #311161
	epatch "${FILESDIR}"/5.2.3/${PN}-5.2.3-lib-search-path.patch

	# stop build for errors in subdirs
	epatch "${FILESDIR}"/5.2.3/${PN}-5.2.3-Makefile.patch

	# bat needs to respect LDFLAGS
	epatch "${FILESDIR}"/5.2.3/${PN}-5.2.3-ldflags.patch

	# bug #328701
	epatch "${FILESDIR}"/5.2.3/${PN}-5.2.3-openssl-1.patch

	epatch "${FILESDIR}"/7.0.2/${PN}-7.0.2-fix-static.patch

	# do not strip binaries
	sed -i -e "s/strip /# strip /" src/filed/Makefile.in || die
	sed -i -e "s/strip /# strip /" src/console/Makefile.in || die

	# fix file not found error during make depend
	epatch "${FILESDIR}"/7.0.2/${PN}-7.0.2-depend.patch

	# Fix systemd unit files:
	# bug 497748
	sed -i -e '/Requires/d' platforms/systemd/*.service.in || die
	sed -i -e '/StandardOutput/d' platforms/systemd/*.service.in || die
	# bug 504370
	sed -i -e '/Alias=bacula-dir/d' platforms/systemd/bacula-dir.service.in || die
}

src_configure() {
	local myconf=''

	if use bacula-clientonly; then
		myconf="${myconf} \
			$(use_enable bacula-clientonly client-only) \
			$(use_enable !static libtool) \
			$(use_enable static static-cons) \
			$(use_enable static static-fd)"
	else
		myconf="${myconf} \
			$(use_enable !bacula-nodir build-dird) \
			$(use_enable !bacula-nosd build-stored)"
		# bug #311099
		# database support needed by dir-only *and* sd-only
		# build as well (for building bscan, btape, etc.)
		myconf="${myconf} \
			--with-${mydbtype} \
			--enable-batch-insert"
	fi

	# do not build bat if 'static' clientonly
	if ! use bacula-clientonly || ! use static; then
		myconf="${myconf} \
			$(use_enable qt4 bat)"
	fi

	myconf="${myconf} \
		$(use_with X x) \
		$(use_enable !readline conio) \
		$(use_enable readline) \
		$(use_with readline readline /usr) \
		$(use_with ssl openssl) \
		$(use_enable ipv6) \
		$(use_enable acl) \
		$(use_with tcpd tcp-wrappers)"

	econf \
		--libdir=/usr/$(get_libdir) \
		--docdir=/usr/share/doc/${PF} \
		--htmldir=/usr/share/doc/${PF}/html \
		--with-pid-dir=/var/run \
		--sysconfdir=/etc/bacula \
		--with-subsys-dir=/var/lock/subsys \
		--with-working-dir=/var/lib/bacula \
		--with-logdir=/var/lib/bacula \
		--with-scriptdir=/usr/libexec/bacula \
		--with-systemd=$(systemd_get_unitdir) \
		--with-dir-user=bacula \
		--with-dir-group=bacula \
		--with-sd-user=root \
		--with-sd-group=bacula \
		--with-fd-user=root \
		--with-fd-group=bacula \
		--enable-smartalloc \
		--disable-afs \
		--host=${CHOST} \
		${myconf}
	# correct configuration for QT based bat
	if use qt4 ; then
		pushd src/qt-console
		eqmake4
		popd
	fi
}

src_compile() {
	# Make build log verbose (bug #447806)
	emake NO_ECHO=""
}

src_install() {
	emake DESTDIR="${D}" install
	doicon scripts/bacula.png

	# install bat icon and desktop file when enabled
	# (for some reason ./configure doesn't pick this up)
	if use qt4 && ! use static ; then
		doicon src/qt-console/images/bat_icon.png
		domenu scripts/bat.desktop
	fi

	# remove some scripts we don't need at all
	rm -f "${D}"/usr/libexec/bacula/{bacula,bacula-ctl-dir,bacula-ctl-fd,bacula-ctl-sd,startmysql,stopmysql}

	# rename statically linked apps
	if use bacula-clientonly && use static ; then
		pushd "${D}"/usr/sbin || die
		mv static-bacula-fd bacula-fd || die
		mv static-bconsole bconsole || die
		popd || die
	fi

	# extra files which 'make install' doesn't cover
	if ! use bacula-clientonly; then
	    # the database update scripts
		diropts -m0750
		insinto /usr/libexec/bacula/updatedb
		insopts -m0754
		doins "${S}"/updatedb/*
		fperms 0640 /usr/libexec/bacula/updatedb/README

		# the logrotate configuration
		# (now unconditional wrt bug #258187)
		diropts -m0755
		insinto /etc/logrotate.d
		insopts -m0644
		newins "${S}"/scripts/logrotate bacula

		# the logwatch scripts
		if use logwatch; then
			diropts -m0750
			dodir /etc/log.d/scripts/services
			dodir /etc/log.d/scripts/shared
			dodir /etc/log.d/conf/logfiles
			dodir /etc/log.d/conf/services
			pushd "${S}"/scripts/logwatch >&/dev/null || die
			emake DESTDIR="${D}" install
			popd >&/dev/null || die
		fi
	fi

	if ! use qt4; then
		rm -vf "${D}"/usr/share/man/man1/bat.1*
	fi
	rm -vf "${D}"/usr/share/man/man1/bacula-tray-monitor.1*
	if use bacula-clientonly || use bacula-nodir; then
		rm -vf "${D}"/usr/share/man/man8/bacula-dir.8*
		rm -vf "${D}"/usr/share/man/man8/dbcheck.8*
		rm -vf "${D}"/usr/share/man/man1/bsmtp.1*
		rm -vf "${D}"/usr/libexec/bacula/create_*_database
		rm -vf "${D}"/usr/libexec/bacula/drop_*_database
		rm -vf "${D}"/usr/libexec/bacula/make_*_tables
		rm -vf "${D}"/usr/libexec/bacula/update_*_tables
		rm -vf "${D}"/usr/libexec/bacula/drop_*_tables
		rm -vf "${D}"/usr/libexec/bacula/grant_*_privileges
		rm -vf "${D}"/usr/libexec/bacula/*_catalog_backup
	fi
	if use bacula-clientonly || use bacula-nosd; then
		rm -vf "${D}"/usr/share/man/man8/bacula-sd.8*
		rm -vf "${D}"/usr/share/man/man8/bcopy.8*
		rm -vf "${D}"/usr/share/man/man8/bextract.8*
		rm -vf "${D}"/usr/share/man/man8/bls.8*
		rm -vf "${D}"/usr/share/man/man8/bscan.8*
		rm -vf "${D}"/usr/share/man/man8/btape.8*
		rm -vf "${D}"/usr/libexec/bacula/disk-changer
		rm -vf "${D}"/usr/libexec/bacula/mtx-changer
		rm -vf "${D}"/usr/libexec/bacula/dvd-handler
	fi

	# documentation
	dodoc ChangeLog ReleaseNotes SUPPORT technotes

	# install examples (bug #457504)
	if use examples; then
		docinto examples/
		dodoc -r examples/*
	fi

	# vim-files
	if use vim-syntax; then
		insinto /usr/share/vim/vimfiles/syntax
		doins scripts/bacula.vim
		insinto /usr/share/vim/vimfiles/ftdetect
		newins scripts/filetype.vim bacula_ft.vim
	fi

	# setup init scripts
	myscripts="bacula-fd"
	if ! use bacula-clientonly; then
		if ! use bacula-nodir; then
			myscripts="${myscripts} bacula-dir"
		fi
		if ! use bacula-nosd; then
			myscripts="${myscripts} bacula-sd"
		fi
	fi
	for script in ${myscripts}; do
		# copy over init script and config to a temporary location
		# so we can modify them as needed
		cp "${FILESDIR}/${script}".confd "${T}/${script}".confd || die "failed to copy ${script}.confd"
		cp "${FILESDIR}/${script}".initd "${T}/${script}".initd || die "failed to copy ${script}.initd"

		# now set the database dependancy for the director init script
		case "${script}" in
			bacula-dir)
				case "${mydbtype}" in
					sqlite3)
						# sqlite3 databases don't have a daemon
						sed -i -e 's/need "%database%"/:/g' "${T}/${script}".initd || die
						;;
					*)
						# all other databases have daemons
						sed -i -e "s:%database%:${mydbtype}:" "${T}/${script}".initd || die
						;;
				esac
				;;
			*)
				;;
		esac

		# install init script and config
		newinitd "${T}/${script}".initd "${script}"
		newconfd "${T}/${script}".confd "${script}"
	done

	systemd_dounit "${S}"/platforms/systemd/bacula-{dir,fd,sd}.service
	systemd_dotmpfilesd "${S}"/platforms/systemd/bacula.conf

	# make sure the working directory exists
	diropts -m0750
	keepdir /var/lib/bacula

	# make sure bacula group can execute bacula libexec scripts
	fowners -R root:bacula /usr/libexec/bacula
}

pkg_postinst() {
	if use bacula-clientonly; then
		fowners root:bacula /var/lib/bacula
	else
		fowners bacula:bacula /var/lib/bacula
	fi

	if ! use bacula-clientonly && ! use bacula-nodir; then
		einfo
		einfo "If this is a new install, you must create the ${mydbtype} databases with:"
		einfo "  /usr/libexec/bacula/create_${mydbtype}_database"
		einfo "  /usr/libexec/bacula/make_${mydbtype}_tables"
		einfo "  /usr/libexec/bacula/grant_${mydbtype}_privileges"
		einfo
	fi

	if use sqlite3; then
		einfo
		einfo "Be aware that Bacula does not officially support SQLite database anymore."
		einfo "Best use it only for a client-only installation. See Bug #445540."
		einfo
	fi

	einfo "Please note that 'bconsole' will always be installed. To compile 'bat'"
	einfo "you have to enable 'USE=qt4'."
	einfo
}
