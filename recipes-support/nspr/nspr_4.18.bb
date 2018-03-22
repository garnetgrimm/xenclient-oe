SUMMARY = "Netscape Portable Runtime Library"
HOMEPAGE =  "http://www.mozilla.org/projects/nspr/"
LICENSE = "GPL-2.0 | MPL-2.0 | LGPL-2.1"
LIC_FILES_CHKSUM = "file://configure.in;beginline=3;endline=6;md5=90c2fdee38e45d6302abcfe475c8b5c5 \
                    file://Makefile.in;beginline=4;endline=38;md5=beda1dbb98a515f557d3e58ef06bca99"
SECTION = "libs/network"

SRC_URI = "http://ftp.mozilla.org/pub/nspr/releases/v${PV}/src/nspr-${PV}.tar.gz \
           file://remove-rpath-from-tests.patch \
           file://fix-build-on-x86_64.patch \
           file://remove-srcdir-from-configure-in.patch \
           file://0002-Add-nios2-support.patch \
           file://0001-include-stdint.h-for-SSIZE_MAX-and-SIZE_MAX-definiti.patch \
           file://0001-md-Fix-build-with-musl.patch \
           file://nspr.pc.in \
"

CACHED_CONFIGUREVARS_append_libc-musl = " CFLAGS='${CFLAGS} -D_PR_POLL_AVAILABLE \
                                          -D_PR_HAVE_OFF64_T -D_PR_INET6 -D_PR_HAVE_INET_NTOP \
                                          -D_PR_HAVE_GETHOSTBYNAME2 -D_PR_HAVE_GETADDRINFO \
                                          -D_PR_INET6_PROBE -DNO_DLOPEN_NULL'"

UPSTREAM_CHECK_URI = "http://ftp.mozilla.org/pub/nspr/releases/"
UPSTREAM_CHECK_REGEX = "v(?P<pver>\d+(\.\d+)+)/"

SRC_URI[md5sum] = "2a558f9aeb109bfb16d78bdc42033a1e"
SRC_URI[sha256sum] = "b89657c09bf88707d06ac238b8930d3ae08de68cb3edccfdc2e3dc97f9c8fb34"

CVE_PRODUCT = "netscape_portable_runtime"

S = "${WORKDIR}/nspr-${PV}/nspr"

RDEPENDS_${PN}-dev += "perl"
TARGET_CC_ARCH += "${LDFLAGS}"

inherit autotools

do_compile_prepend() {
	oe_runmake CROSS_COMPILE=1 CFLAGS="-DXP_UNIX ${BUILD_CFLAGS}" LDFLAGS="" CC="${BUILD_CC}" -C config export
}

do_install_append() {
    install -D ${WORKDIR}/nspr.pc.in ${D}${libdir}/pkgconfig/nspr.pc
    sed -i  \
    -e 's:NSPRVERSION:${PV}:g' \
    -e 's:OEPREFIX:${prefix}:g' \
    -e 's:OELIBDIR:${libdir}:g' \
    -e 's:OEINCDIR:${includedir}:g' \
    -e 's:OEEXECPREFIX:${exec_prefix}:g' \
    ${D}${libdir}/pkgconfig/nspr.pc

    # delete compile-et.pl and perr.properties from ${bindir} because these are
    # only used to generate prerr.c and prerr.h files from prerr.et at compile
    # time
    rm ${D}${bindir}/compile-et.pl ${D}${bindir}/prerr.properties
}

FILES_${PN} = "${libdir}/lib*.so"
FILES_${PN}-dev = "${bindir}/* ${libdir}/nspr/tests/* ${libdir}/pkgconfig \
                ${includedir}/* ${datadir}/aclocal/* "

BBCLASSEXTEND = "native nativesdk"
