# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5


POSTGRES_COMPAT=( 9.{1..6} )

inherit base multilib postgres-multi user

MY_P="${PN/2/-II}-${PV}"

DESCRIPTION="Connection pool server for PostgreSQL"
HOMEPAGE="http://www.pgpool.net/"
SRC_URI="http://www.pgpool.net/download.php?f=${MY_P}.tar.gz -> ${MY_P}.tar.gz"
LICENSE="BSD"
SLOT="0"

KEYWORDS="~amd64 ~x86"

IUSE="memcached pam ssl static-libs"

RDEPEND="
	${POSTGRES_DEPEND}
	memcached? ( dev-libs/libmemcached )
	pam? ( sys-auth/pambase )
	ssl? ( dev-libs/openssl )
"
DEPEND="${RDEPEND}
	sys-devel/bison
	!!dev-db/pgpool
"

S=${WORKDIR}/${MY_P}

pkg_setup() {
	postgres_new_user pgpool

	postgres-multi_pkg_setup
}

src_prepare() {
	epatch "${FILESDIR}/pgpool2-3.5.0-path-fix.patch" \
		   "${FILESDIR}/pgpool-3.5.0-respect-pg-config-envvar.patch"

	local pg_config_manual="$(pg_config --includedir)/pg_config_manual.h"
	local pgsql_socket_dir=$(grep DEFAULT_PGSOCKET_DIR "${pg_config_manual}" | \
		sed 's|.*\"\(.*\)\"|\1|g')
	local pgpool_socket_dir="$(dirname $pgsql_socket_dir)/pgpool"

	sed "s|@PGSQL_SOCKETDIR@|${pgsql_socket_dir}|g" \
		-i src/sample/pgpool.conf.sample* src/include/pool.h || die

	sed "s|@PGPOOL_SOCKETDIR@|${pgpool_socket_dir}|g" \
		-i src/sample/pgpool.conf.sample* src/include/pool.h || die

	postgres-multi_src_prepare
}

src_configure() {
	local myconf
	use memcached && \
		myconf="--with-memcached=\"${EROOT%/}/usr/include/libmemcached\""
	use pam && myconf+=' --with-pam'

	postgres-multi_foreach econf \
		--disable-rpath \
		--sysconfdir="${EROOT%/}/etc/${PN}" \
		--with-pgsql-includedir='/usr/include/postgresql-@PG_SLOT@' \
		--with-pgsql-libdir="/usr/$(get_libdir)/postgresql-@PG_SLOT@/$(get_libdir)" \
		$(use_with ssl openssl) \
		$(use_enable static-libs static) \
		${myconf}


}

src_compile() {
	#postgres-multi_forbest emake
	postgres-multi_foreach emake -C src/sql
}

src_install() {
	# We only need the best stuff installed
	#postgres-multi_forbest emake DESTDIR="${D}" install

	# Except for the extension and .so files that PostgreSQL slot needs
	postgres-multi_foreach emake DESTDIR="${D}" -C src/sql install

	newinitd "${FILESDIR}/${PN}.initd" ${PN}
	newconfd "${FILESDIR}/${PN}.confd" ${PN}

	# Documentation!
	dodoc NEWS TODO doc/where_to_send_queries.{pdf,odg}
	dohtml -r doc/*

	# Examples and extras
	# mv some files that get installed to /usr/share/pgpool-II so that
	# they all wind up in the same place
	mv "${ED%/}/usr/share/${PN/2/-II}" "${ED%/}/usr/share/${PN}" || die
	into "/usr/share/${PN}"
	dobin doc/{pgpool_remote_start,basebackup.sh}
	insinto "/usr/share/${PN}"
	doins doc/recovery.conf.sample

	# One more thing: Evil la files!
	find "${ED}" -name '*.la' -exec rm -f {} +
}