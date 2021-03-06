# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/slony1/slony1-2.2.3.ebuild,v 1.1 2014/07/24 06:29:27 patrick Exp $

EAPI="4"

inherit eutils versionator

IUSE="doc perl"

DESCRIPTION="A replication system for the PostgreSQL Database Management System"
HOMEPAGE="http://slony.info/"

# ${P}-docs.tar.bz2 contains man pages as well as additional documentation
MAJ_PV=$(get_version_component_range 1-2)
SRC_URI="http://main.slony.info/downloads/${MAJ_PV}/source/${P}.tar.bz2
		 http://main.slony.info/downloads/${MAJ_PV}/source/${P}-docs.tar.bz2"

LICENSE="BSD GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~ppc ~x86"

DEPEND="|| (
			dev-db/postgresql:9.4[server,threads]
			dev-db/postgresql:9.3[server,threads]
			dev-db/postgresql:9.2[server,threads]
			dev-db/postgresql:9.1[server,threads]
			dev-db/postgresql:9.0[server,threads]
			dev-db/postgresql:8.4[server,threads]
			dev-db/postgresql:8.3[server,threads]
		)
		perl? ( dev-perl/DBD-Pg )
"

pkg_setup() {
	local PGSLOT="$(postgresql-config show)"
	if [[ ${PGSLOT//.} < 83 ]] ; then
		eerror "You must build ${CATEGORY}/${PN} against PostgreSQL 8.3 or higher."
		eerror "Set an appropriate slot with postgresql-config."
		die "postgresql-config not set to 8.3 or higher."
	fi
}

src_configure() {
	local myconf
	# --with-perltools is interpreted as one of two things: Enable
	# (yes), or an installation path; perltools=no installs the scripts in /no
	use perl && myconf='--with-perltools'
	econf ${myconf}
}

src_install() {
	emake DESTDIR="${D}" install

	dodoc INSTALL README SAMPLE TODO UPGRADING share/slon.conf-sample

	if use doc ; then
		cd "${S}"/doc
		dohtml -r *
	fi

	newinitd "${FILESDIR}"/slony1.init slony1
	newconfd "${FILESDIR}"/slony1.conf slony1
}
