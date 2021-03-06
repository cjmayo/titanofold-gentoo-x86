# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-ml/postgresql-ocaml/postgresql-ocaml-2.0.5.ebuild,v 1.3 2014/08/10 20:43:29 slyfox Exp $

EAPI=5

OASIS_BUILD_DOCS=1

inherit oasis

DESCRIPTION="A package for ocaml that provides access to PostgreSQL databases"
SRC_URI="http://bitbucket.org/mmottl/postgresql-ocaml/downloads/${P}.tar.gz"
HOMEPAGE="http://bitbucket.org/mmottl/postgresql-ocaml"
IUSE="examples"

DEPEND="dev-db/postgresql[server]"
RDEPEND="${DEPEND}"

SLOT="0/${PV}"
LICENSE="LGPL-2"
KEYWORDS="~amd64 ~ppc x86"

DOCS=( "AUTHORS.txt" "CHANGES.txt" "README.md" )

src_install() {
	oasis_src_install
	if use examples ; then
		insinto /usr/share/doc/${PF}
		doins -r examples
	fi
}
