# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-perl/DateTime/DateTime-1.030.0.ebuild,v 1.11 2014/04/29 15:00:43 zlogene Exp $

EAPI=5

MODULE_AUTHOR=SARTAK
MODULE_VERSION=0.04
inherit perl-module

DESCRIPTION="Extract probable dates from strings"

LICENSE="Artistic-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"

RDEPEND=""
DEPEND="${RDEPEND}
	dev-perl/Class-Data-Inheritable
	>=dev-perl/DateTime-Format-Natural-0.60
	test? (
		dev-perl/Test-More
		dev-perl/Test-MockTime
	)
"

SRC_TEST="do"
