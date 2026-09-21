#!/usr/bin/env bash
# ==============================================================================
# Linux From Scratch (LFS) 13.1-systemd - Chapter 8: Installing Basic System Software
# Automated Complete Installation Script (Test suites skipped for maximum speed)
# LFS Chapter 8 chroot runner: execute this script from inside the LFS chroot.
# ==============================================================================
set -eo pipefail

# ------------------------------------------------------------------------------
# Environment & Configuration
# ------------------------------------------------------------------------------
SOURCES_DIR="${SOURCES_DIR:-/sources}"
MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
export MAKEFLAGS

# Inside LFS chroot, / is already the LFS root. Do not use an external $LFS path.
unset LFS 2>/dev/null || true
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
LFS_TIMEZONE="${LFS_TIMEZONE:-UTC}"
GROFF_PAGE="${GROFF_PAGE:-A4}"
ROOT_PASSWORD="${ROOT_PASSWORD:-root}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-5}"

# Colors
BOLD="\033[1m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

log_step() {
    local step="$1"
    local name="$2"
    echo -e "\n${BLUE}==============================================================================${RESET}"
    echo -e "${GREEN}[${step}] Building ${name}...${RESET}"
    echo -e "${BLUE}==============================================================================${RESET}"
}

log_info() {
    echo -e "${YELLOW}[INFO]${RESET} $1"
}

log_err() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

trap 'log_err "Installation failed at line $LINENO in ${FUNCNAME[0]:-main}!"; exit 1' ERR

check_environment() {
    if [ "$(id -u)" -ne 0 ]; then
        log_err "This script must be run as root (inside LFS chroot)!"
        exit 1
    fi
    if [ ! -d "$SOURCES_DIR" ]; then
        log_err "Sources directory $SOURCES_DIR not found!"
        exit 1
    fi
    cd "$SOURCES_DIR"
}

# Section 8.3: Man-pages-6.18
build_man_pages_6_18() {
    log_step "8.3" "Man-pages-6.18"
    cd "$SOURCES_DIR"
    if [ ! -f "man-pages-6.18.tar.xz" ]; then
        log_err "Tarball man-pages-6.18.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "man-pages-6.18"
    tar -xf "man-pages-6.18.tar.xz"
    cd "man-pages-6.18"

    rm -v man3/crypt*

    make -R GIT=false prefix=/usr install

    cd "$SOURCES_DIR"
    rm -rf "man-pages-6.18"
    log_info "Completed Man-pages-6.18 successfully!"
}

# Section 8.4: Iana-Etc-20260805
build_iana_etc_20260805() {
    log_step "8.4" "Iana-Etc-20260805"
    cd "$SOURCES_DIR"
    if [ ! -f "iana-etc-20260805.tar.gz" ]; then
        log_err "Tarball iana-etc-20260805.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "iana-etc-20260805"
    tar -xf "iana-etc-20260805.tar.gz"
    cd "iana-etc-20260805"

    cp -v services protocols /etc

    cd "$SOURCES_DIR"
    rm -rf "iana-etc-20260805"
    log_info "Completed Iana-Etc-20260805 successfully!"
}

# Section 8.5: Glibc-2.44
build_glibc_2_44() {
    log_step "8.5" "Glibc-2.44"
    cd "$SOURCES_DIR"
    if [ ! -f "glibc-2.44.tar.xz" ]; then
        log_err "Tarball glibc-2.44.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "glibc-2.44"
    tar -xf "glibc-2.44.tar.xz"
    cd "glibc-2.44"

    patch -Np1 -i ../glibc-fhs-1.patch

    patch -Np1 -i ../glibc-2.44-upstream_fixes-1.patch

    mkdir -v build
    cd       build

    ../configure --prefix=/usr                   \
                 --disable-werror                \
                 --disable-nscd                  \
                 libc_cv_slibdir=/usr/lib        \
                 --enable-stack-protector=strong \
                 --enable-kernel=5.10

    make

    touch /etc/ld.so.conf

    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

    rm -f /usr/sbin/nscd

    systemctl disable --now nscd 2>/dev/null || true

    make DESTDIR=$PWD/dest install
    install -vm755 dest/usr/lib/*.so.* /usr/lib

    DIR=$(dirname $(gcc -print-libgcc-file-name))
    [ -e $DIR/include/limits.h ]    || mv $DIR/include{-fixed,}/limits.h
    [ -e $DIR/include/syslimits.h ] || mv $DIR/include{-fixed,}/syslimits.h
    rm -rfv $DIR/include-fixed/*
    unset DIR

    make install

    sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

    localedef -i C -f UTF-8 C.UTF-8
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
    localedef -i de_DE -f ISO-8859-1 de_DE
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
    localedef -i de_DE -f UTF-8 de_DE.UTF-8
    localedef -i el_GR -f ISO-8859-7 el_GR
    localedef -i en_GB -f ISO-8859-1 en_GB
    localedef -i en_GB -f UTF-8 en_GB.UTF-8
    localedef -i en_HK -f ISO-8859-1 en_HK
    localedef -i en_PH -f ISO-8859-1 en_PH
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
    localedef -i es_ES -f ISO-8859-15 es_ES@euro
    localedef -i es_MX -f ISO-8859-1 es_MX
    localedef -i fa_IR -f UTF-8 fa_IR
    localedef -i fr_FR -f ISO-8859-1 fr_FR
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
    localedef -i is_IS -f ISO-8859-1 is_IS
    localedef -i is_IS -f UTF-8 is_IS.UTF-8
    localedef -i it_IT -f ISO-8859-1 it_IT
    localedef -i it_IT -f ISO-8859-15 it_IT@euro
    localedef -i it_IT -f UTF-8 it_IT.UTF-8
    localedef -i ja_JP -f EUC-JP ja_JP
    localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
    localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
    localedef -i se_NO -f UTF-8 se_NO.UTF-8
    localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
    localedef -i zh_CN -f GB18030 zh_CN.GB18030
    localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
    localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

    make localedata/install-locales

    cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

    tar -xf ../../tzdata2026c.tar.gz
    
    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}
    
    for tz in etcetera southamerica northamerica europe africa antarctica  \
              asia australasia backward; do
        zic -L /dev/null   -d $ZONEINFO       ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        zic -L leapseconds -d $ZONEINFO/right ${tz}
    done
    
    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO tz

    ln -sfv /usr/share/zoneinfo/$LFS_TIMEZONE /etc/localtime

    cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

    cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
    mkdir -pv /etc/ld.so.conf.d

    cd "$SOURCES_DIR"
    rm -rf "glibc-2.44"
    log_info "Completed Glibc-2.44 successfully!"
}

# Section 8.6: Zlib-1.3.2
build_zlib_1_3_2() {
    log_step "8.6" "Zlib-1.3.2"
    cd "$SOURCES_DIR"
    if [ ! -f "zlib-1.3.2.tar.gz" ]; then
        log_err "Tarball zlib-1.3.2.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "zlib-1.3.2"
    tar -xf "zlib-1.3.2.tar.gz"
    cd "zlib-1.3.2"

    ./configure --prefix=/usr

    make

    make install

    rm -fv /usr/lib/libz.a

    cd "$SOURCES_DIR"
    rm -rf "zlib-1.3.2"
    log_info "Completed Zlib-1.3.2 successfully!"
}

# Section 8.7: Bzip2-1.0.8
build_bzip2_1_0_8() {
    log_step "8.7" "Bzip2-1.0.8"
    cd "$SOURCES_DIR"
    if [ ! -f "bzip2-1.0.8.tar.gz" ]; then
        log_err "Tarball bzip2-1.0.8.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "bzip2-1.0.8"
    tar -xf "bzip2-1.0.8.tar.gz"
    cd "bzip2-1.0.8"

    patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch

    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile

    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

    make -f Makefile-libbz2_so
    make clean

    make

    make PREFIX=/usr install

    cp -av libbz2.so.* /usr/lib
    ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so

    ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1

    cp -v bzip2-shared /usr/bin/bzip2
    for i in /usr/bin/{bzcat,bunzip2}; do
      ln -sfv bzip2 $i
    done

    rm -fv /usr/lib/libbz2.a

    cd "$SOURCES_DIR"
    rm -rf "bzip2-1.0.8"
    log_info "Completed Bzip2-1.0.8 successfully!"
}

# Section 8.8: Xz-5.8.3
build_xz_5_8_3() {
    log_step "8.8" "Xz-5.8.3"
    cd "$SOURCES_DIR"
    if [ ! -f "xz-5.8.3.tar.xz" ]; then
        log_err "Tarball xz-5.8.3.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "xz-5.8.3"
    tar -xf "xz-5.8.3.tar.xz"
    cd "xz-5.8.3"

    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/xz-5.8.3

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "xz-5.8.3"
    log_info "Completed Xz-5.8.3 successfully!"
}

# Section 8.9: Lz4-1.10.0
build_lz4_1_10_0() {
    log_step "8.9" "Lz4-1.10.0"
    cd "$SOURCES_DIR"
    if [ ! -f "lz4-1.10.0.tar.gz" ]; then
        log_err "Tarball lz4-1.10.0.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "lz4-1.10.0"
    tar -xf "lz4-1.10.0.tar.gz"
    cd "lz4-1.10.0"

    make BUILD_STATIC=no PREFIX=/usr

    make BUILD_STATIC=no PREFIX=/usr install

    cd "$SOURCES_DIR"
    rm -rf "lz4-1.10.0"
    log_info "Completed Lz4-1.10.0 successfully!"
}

# Section 8.10: Zstd-1.5.7
build_zstd_1_5_7() {
    log_step "8.10" "Zstd-1.5.7"
    cd "$SOURCES_DIR"
    if [ ! -f "zstd-1.5.7.tar.gz" ]; then
        log_err "Tarball zstd-1.5.7.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "zstd-1.5.7"
    tar -xf "zstd-1.5.7.tar.gz"
    cd "zstd-1.5.7"

    make prefix=/usr

    make prefix=/usr install

    rm -v /usr/lib/libzstd.a

    cd "$SOURCES_DIR"
    rm -rf "zstd-1.5.7"
    log_info "Completed Zstd-1.5.7 successfully!"
}

# Section 8.11: File-5.48
build_file_5_48() {
    log_step "8.11" "File-5.48"
    cd "$SOURCES_DIR"
    if [ ! -f "file-5.48.tar.gz" ]; then
        log_err "Tarball file-5.48.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "file-5.48"
    tar -xf "file-5.48.tar.gz"
    cd "file-5.48"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "file-5.48"
    log_info "Completed File-5.48 successfully!"
}

# Section 8.12: Readline-8.3
build_readline_8_3() {
    log_step "8.12" "Readline-8.3"
    cd "$SOURCES_DIR"
    if [ ! -f "readline-8.3.tar.gz" ]; then
        log_err "Tarball readline-8.3.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "readline-8.3"
    tar -xf "readline-8.3.tar.gz"
    cd "readline-8.3"

    sed -i '/MV.*old/d' Makefile.in
    sed -i '/{OLDSUFF}/c:' support/shlib-install

    sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf

    sed -e '270a\
         else\
           chars_avail = 1;'      \
        -e '288i\   result = -1;' \
        -i.orig input.c

    ./configure --prefix=/usr    \
                --disable-static \
                --with-curses    \
                --docdir=/usr/share/doc/readline-8.3

    make SHLIB_LIBS="-lncursesw"

    make install

    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3

    cd "$SOURCES_DIR"
    rm -rf "readline-8.3"
    log_info "Completed Readline-8.3 successfully!"
}

# Section 8.13: Pcre2-10.47
build_pcre2_10_47() {
    log_step "8.13" "Pcre2-10.47"
    cd "$SOURCES_DIR"
    if [ ! -f "pcre2-10.47.tar.bz2" ]; then
        log_err "Tarball pcre2-10.47.tar.bz2 not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "pcre2-10.47"
    tar -xf "pcre2-10.47.tar.bz2"
    cd "pcre2-10.47"

    ./configure --prefix=/usr                       \
                --docdir=/usr/share/doc/pcre2-10.47 \
                --enable-unicode                    \
                --enable-jit                        \
                --enable-pcre2-16                   \
                --enable-pcre2-32                   \
                --enable-pcre2grep-libz             \
                --enable-pcre2grep-libbz2           \
                --enable-pcre2test-libreadline      \
                --disable-static

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "pcre2-10.47"
    log_info "Completed Pcre2-10.47 successfully!"
}

# Section 8.14: M4-1.4.21
build_m4_1_4_21() {
    log_step "8.14" "M4-1.4.21"
    cd "$SOURCES_DIR"
    if [ ! -f "m4-1.4.21.tar.xz" ]; then
        log_err "Tarball m4-1.4.21.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "m4-1.4.21"
    tar -xf "m4-1.4.21.tar.xz"
    cd "m4-1.4.21"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "m4-1.4.21"
    log_info "Completed M4-1.4.21 successfully!"
}

# Section 8.15: Bc-7.0.3
build_bc_7_0_3() {
    log_step "8.15" "Bc-7.0.3"
    cd "$SOURCES_DIR"
    if [ ! -f "bc-7.0.3.tar.xz" ]; then
        log_err "Tarball bc-7.0.3.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "bc-7.0.3"
    tar -xf "bc-7.0.3.tar.xz"
    cd "bc-7.0.3"

    CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "bc-7.0.3"
    log_info "Completed Bc-7.0.3 successfully!"
}

# Section 8.16: Flex-2.6.4
build_flex_2_6_4() {
    log_step "8.16" "Flex-2.6.4"
    cd "$SOURCES_DIR"
    if [ ! -f "flex-2.6.4.tar.gz" ]; then
        log_err "Tarball flex-2.6.4.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "flex-2.6.4"
    tar -xf "flex-2.6.4.tar.gz"
    cd "flex-2.6.4"

    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/flex-2.6.4

    make

    make install

    ln -sv flex   /usr/bin/lex
    ln -sv flex.1 /usr/share/man/man1/lex.1

    cd "$SOURCES_DIR"
    rm -rf "flex-2.6.4"
    log_info "Completed Flex-2.6.4 successfully!"
}

# Section 8.17: Tcl-8.6.18
build_tcl_8_6_18() {
    log_step "8.17" "Tcl-8.6.18"
    cd "$SOURCES_DIR"
    if [ ! -f "tcl8.6.18-src.tar.gz" ]; then
        log_err "Tarball tcl8.6.18-src.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "tcl8.6.18"
    tar -xf "tcl8.6.18-src.tar.gz"
    cd "tcl8.6.18"

    SRCDIR=$(pwd)
    cd unix
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --disable-rpath

    make
    
    sed -e "s|$SRCDIR/unix|/usr/lib|" \
        -e "s|$SRCDIR|/usr/include|"  \
        -i tclConfig.sh
    
    sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.13|/usr/lib/tdbc1.1.13|" \
        -e "s|$SRCDIR/pkgs/tdbc1.1.13/generic|/usr/include|"     \
        -e "s|$SRCDIR/pkgs/tdbc1.1.13/library|/usr/lib/tcl8.6|"  \
        -e "s|$SRCDIR/pkgs/tdbc1.1.13|/usr/include|"             \
        -i pkgs/tdbc1.1.13/tdbcConfig.sh
    
    sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.7|/usr/lib/itcl4.3.7|" \
        -e "s|$SRCDIR/pkgs/itcl4.3.7/generic|/usr/include|"    \
        -e "s|$SRCDIR/pkgs/itcl4.3.7|/usr/include|"            \
        -i pkgs/itcl4.3.7/itclConfig.sh
    
    unset SRCDIR

    make install 
    chmod 644 /usr/lib/libtclstub8.6.a

    chmod -v u+w /usr/lib/libtcl8.6.so

    make install-private-headers

    ln -sfv tclsh8.6 /usr/bin/tclsh

    mv -v /usr/share/man/man3/{Thread,Tcl_Thread}.3

    cd ..
    tar -xf ../tcl8.6.18-html.tar.gz --strip-components=1
    mkdir -v -p /usr/share/doc/tcl-8.6.18
    cp -v -r  ./html/* /usr/share/doc/tcl-8.6.18

    cd "$SOURCES_DIR"
    rm -rf "tcl8.6.18"
    log_info "Completed Tcl-8.6.18 successfully!"
}

# Section 8.18: Expect-5.45.4
build_expect_5_45_4() {
    log_step "8.18" "Expect-5.45.4"
    cd "$SOURCES_DIR"
    if [ ! -f "expect5.45.4.tar.gz" ]; then
        log_err "Tarball expect5.45.4.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "expect5.45.4"
    tar -xf "expect5.45.4.tar.gz"
    cd "expect5.45.4"

    python3 -c 'from pty import spawn; spawn(["echo", "ok"])'

    patch -Np1 -i ../expect-5.45.4-gcc15-1.patch

    ./configure --prefix=/usr           \
                --with-tcl=/usr/lib     \
                --enable-shared         \
                --disable-rpath         \
                --mandir=/usr/share/man \
                --with-tclinclude=/usr/include

    make

    make install
    ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

    cd "$SOURCES_DIR"
    rm -rf "expect5.45.4"
    log_info "Completed Expect-5.45.4 successfully!"
}

# Section 8.19: DejaGNU-1.6.3
build_dejagnu_1_6_3() {
    log_step "8.19" "DejaGNU-1.6.3"
    cd "$SOURCES_DIR"
    if [ ! -f "dejagnu-1.6.3.tar.gz" ]; then
        log_err "Tarball dejagnu-1.6.3.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "dejagnu-1.6.3"
    tar -xf "dejagnu-1.6.3.tar.gz"
    cd "dejagnu-1.6.3"

    mkdir -v build
    cd       build

    ../configure --prefix=/usr
    makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
    makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi

    make install
    install -v -dm755  /usr/share/doc/dejagnu-1.6.3
    install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3

    cd "$SOURCES_DIR"
    rm -rf "dejagnu-1.6.3"
    log_info "Completed DejaGNU-1.6.3 successfully!"
}

# Section 8.20: Ninja-1.13.2
build_ninja_1_13_2() {
    log_step "8.20" "Ninja-1.13.2"
    cd "$SOURCES_DIR"
    if [ ! -f "ninja-1.13.2.tar.gz" ]; then
        log_err "Tarball ninja-1.13.2.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "ninja-1.13.2"
    tar -xf "ninja-1.13.2.tar.gz"
    cd "ninja-1.13.2"

    sed -i '/int Guess/a \
      int   j = 0;\
      char* jobs = getenv( "NINJAJOBS" );\
      if ( jobs != NULL ) j = atoi( jobs );\
      if ( j > 0 ) return j;\
    ' src/ninja.cc

    python3 configure.py --bootstrap --verbose

    install -vm755 ninja /usr/bin/
    install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
    install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

    cd "$SOURCES_DIR"
    rm -rf "ninja-1.13.2"
    log_info "Completed Ninja-1.13.2 successfully!"
}

# Section 8.21: Pkgconf-3.0.5
build_pkgconf_3_0_5() {
    log_step "8.21" "Pkgconf-3.0.5"
    cd "$SOURCES_DIR"
    if [ ! -f "pkgconf-3.0.5.tar.xz" ]; then
        log_err "Tarball pkgconf-3.0.5.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "pkgconf-3.0.5"
    tar -xf "pkgconf-3.0.5.tar.xz"
    cd "pkgconf-3.0.5"

    tar -xf ../meson-1.12.0.tar.gz

    mkdir build
    cd    build
    
    python3 ../meson-1.12.0/meson.py setup --prefix=/usr --buildtype=release ..

    ninja

    ninja install
    mv /usr/share/doc/pkgconf{,-3.0.5}

    ln -sv pkgconf   /usr/bin/pkg-config
    ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1

    cd "$SOURCES_DIR"
    rm -rf "pkgconf-3.0.5"
    log_info "Completed Pkgconf-3.0.5 successfully!"
}

# Section 8.22: Binutils-2.47
build_binutils_2_47() {
    log_step "8.22" "Binutils-2.47"
    cd "$SOURCES_DIR"
    if [ ! -f "binutils-2.47.tar.xz" ]; then
        log_err "Tarball binutils-2.47.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "binutils-2.47"
    tar -xf "binutils-2.47.tar.xz"
    cd "binutils-2.47"

    mkdir -v build
    cd       build

    ../configure --prefix=/usr       \
                 --sysconfdir=/etc   \
                 --enable-ld=default \
                 --enable-plugins    \
                 --enable-shared     \
                 --disable-werror    \
                 --enable-64-bit-bfd \
                 --enable-new-dtags  \
                 --with-system-zlib  \
                 --with-lib-path=/usr/lib \
                 --enable-default-hash-style=gnu

    make tooldir=/usr

    grep '^FAIL:' $(find -name '*.log')

    make tooldir=/usr install

    rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
            /usr/share/doc/gprofng/

    cd "$SOURCES_DIR"
    rm -rf "binutils-2.47"
    log_info "Completed Binutils-2.47 successfully!"
}

# Section 8.23: GMP-6.3.0
build_gmp_6_3_0() {
    log_step "8.23" "GMP-6.3.0"
    cd "$SOURCES_DIR"
    if [ ! -f "gmp-6.3.0.tar.xz" ]; then
        log_err "Tarball gmp-6.3.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "gmp-6.3.0"
    tar -xf "gmp-6.3.0.tar.xz"
    cd "gmp-6.3.0"

    sed -i '/long long t1;/,+1s/()/(...)/' configure

    ./configure --prefix=/usr    \
                --enable-cxx     \
                --disable-static \
                --docdir=/usr/share/doc/gmp-6.3.0

    make
    make html

    make install
    make install-html

    cd "$SOURCES_DIR"
    rm -rf "gmp-6.3.0"
    log_info "Completed GMP-6.3.0 successfully!"
}

# Section 8.24: MPFR-4.2.2
build_mpfr_4_2_2() {
    log_step "8.24" "MPFR-4.2.2"
    cd "$SOURCES_DIR"
    if [ ! -f "mpfr-4.2.2.tar.xz" ]; then
        log_err "Tarball mpfr-4.2.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "mpfr-4.2.2"
    tar -xf "mpfr-4.2.2.tar.xz"
    cd "mpfr-4.2.2"

    ./configure --prefix=/usr        \
                --disable-static     \
                --enable-thread-safe \
                --docdir=/usr/share/doc/mpfr-4.2.2

    make
    make html

    make install
    make install-html

    cd "$SOURCES_DIR"
    rm -rf "mpfr-4.2.2"
    log_info "Completed MPFR-4.2.2 successfully!"
}

# Section 8.25: MPC-1.4.1
build_mpc_1_4_1() {
    log_step "8.25" "MPC-1.4.1"
    cd "$SOURCES_DIR"
    if [ ! -f "mpc-1.4.1.tar.xz" ]; then
        log_err "Tarball mpc-1.4.1.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "mpc-1.4.1"
    tar -xf "mpc-1.4.1.tar.xz"
    cd "mpc-1.4.1"

    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/mpc-1.4.1

    make
    make html

    make install
    make install-html

    cd "$SOURCES_DIR"
    rm -rf "mpc-1.4.1"
    log_info "Completed MPC-1.4.1 successfully!"
}

# Section 8.26: Attr-2.6.0
build_attr_2_6_0() {
    log_step "8.26" "Attr-2.6.0"
    cd "$SOURCES_DIR"
    if [ ! -f "attr-2.6.0.tar.gz" ]; then
        log_err "Tarball attr-2.6.0.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "attr-2.6.0"
    tar -xf "attr-2.6.0.tar.gz"
    cd "attr-2.6.0"

    ./configure --prefix=/usr     \
                --disable-static  \
                --sysconfdir=/etc \
                --docdir=/usr/share/doc/attr-2.6.0

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "attr-2.6.0"
    log_info "Completed Attr-2.6.0 successfully!"
}

# Section 8.27: Acl-2.4.0
build_acl_2_4_0() {
    log_step "8.27" "Acl-2.4.0"
    cd "$SOURCES_DIR"
    if [ ! -f "acl-2.4.0.tar.xz" ]; then
        log_err "Tarball acl-2.4.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "acl-2.4.0"
    tar -xf "acl-2.4.0.tar.xz"
    cd "acl-2.4.0"

    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/acl-2.4.0

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "acl-2.4.0"
    log_info "Completed Acl-2.4.0 successfully!"
}

# Section 8.28: Libcap-2.78
build_libcap_2_78() {
    log_step "8.28" "Libcap-2.78"
    cd "$SOURCES_DIR"
    if [ ! -f "libcap-2.78.tar.xz" ]; then
        log_err "Tarball libcap-2.78.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "libcap-2.78"
    tar -xf "libcap-2.78.tar.xz"
    cd "libcap-2.78"

    sed -i '/install -m.*STA/d' libcap/Makefile

    make prefix=/usr lib=lib

    make prefix=/usr lib=lib install

    cd "$SOURCES_DIR"
    rm -rf "libcap-2.78"
    log_info "Completed Libcap-2.78 successfully!"
}

# Section 8.29: Libxcrypt-4.5.2
build_libxcrypt_4_5_2() {
    log_step "8.29" "Libxcrypt-4.5.2"
    cd "$SOURCES_DIR"
    if [ ! -f "libxcrypt-4.5.2.tar.xz" ]; then
        log_err "Tarball libxcrypt-4.5.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "libxcrypt-4.5.2"
    tar -xf "libxcrypt-4.5.2.tar.xz"
    cd "libxcrypt-4.5.2"

    sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c

    ./configure --prefix=/usr                \
                --enable-hashes=strong,glibc \
                --enable-obsolete-api=no     \
                --disable-static             \
                --disable-failure-tokens

    make

    make install

    make distclean
    ./configure --prefix=/usr                \
                --enable-hashes=strong,glibc \
                --enable-obsolete-api=glibc  \
                --disable-static             \
                --disable-failure-tokens
    make
    cp -av --remove-destination .libs/libcrypt.so.1* /usr/lib

    cd "$SOURCES_DIR"
    rm -rf "libxcrypt-4.5.2"
    log_info "Completed Libxcrypt-4.5.2 successfully!"
}

# Section 8.30: Shadow-4.20.2
build_shadow_4_20_2() {
    log_step "8.30" "Shadow-4.20.2"
    cd "$SOURCES_DIR"
    if [ ! -f "shadow-4.20.2.tar.xz" ]; then
        log_err "Tarball shadow-4.20.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "shadow-4.20.2"
    tar -xf "shadow-4.20.2.tar.xz"
    cd "shadow-4.20.2"

    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

    sed -e 's:#ENCRYPT_METHOD SHA512:ENCRYPT_METHOD YESCRYPT:' \
        -e 's:/var/spool/mail:/var/mail:'                      \
        -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                     \
        -i etc/login.defs

    touch /usr/bin/passwd
    ./configure --sysconfdir=/etc   \
                --disable-static    \
                --with-{b,yes}crypt \
                --without-libbsd    \
                --disable-logind    \
                --with-group-name-max-length=32

    make

    make exec_prefix=/usr install
    make -C man install-man

    pwconv

    grpconv

    mkdir -p /etc/default
    useradd -D --gid 999

    sed -i '/MAIL/s/yes/no/' /etc/default/useradd

    touch /etc/sub{u,g}id

    log_info "Setting root password to \"${ROOT_PASSWORD}\" (can be changed later with passwd)..."
    echo "root:${ROOT_PASSWORD}" | chpasswd
    cd "$SOURCES_DIR"
    rm -rf "shadow-4.20.2"
    log_info "Completed Shadow-4.20.2 successfully!"
}

# Section 8.31: Gawk-5.4.1
build_gawk_5_4_1() {
    log_step "8.31" "Gawk-5.4.1"
    cd "$SOURCES_DIR"
    if [ ! -f "gawk-5.4.1.tar.xz" ]; then
        log_err "Tarball gawk-5.4.1.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "gawk-5.4.1"
    tar -xf "gawk-5.4.1.tar.xz"
    cd "gawk-5.4.1"

    sed -i 's/extras//' Makefile.in

    ./configure --prefix=/usr

    make

    rm -f /usr/bin/gawk-5.4.1
    make install

    ln -sv gawk.1 /usr/share/man/man1/awk.1

    install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.4.1

    cd "$SOURCES_DIR"
    rm -rf "gawk-5.4.1"
    log_info "Completed Gawk-5.4.1 successfully!"
}

# Section 8.32: GCC-16.2.0
build_gcc_16_2_0() {
    log_step "8.32" "GCC-16.2.0"
    cd "$SOURCES_DIR"
    if [ ! -f "gcc-16.2.0.tar.xz" ]; then
        log_err "Tarball gcc-16.2.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "gcc-16.2.0"
    tar -xf "gcc-16.2.0.tar.xz"
    cd "gcc-16.2.0"

    case $(uname -m) in
      x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
      ;;
    esac

    mkdir -v build
    cd       build

    ../configure --prefix=/usr            \
                 LD=ld                    \
                 --enable-languages=c,c++ \
                 --enable-default-pie     \
                 --enable-default-ssp     \
                 --enable-host-pie        \
                 --enable-targets=all     \
                 --disable-multilib       \
                 --disable-bootstrap      \
                 --disable-fixincludes    \
                 --with-system-zlib

    make

    ulimit -s -H unlimited

    make install

    chown -v -R root:root $(gcc -print-file-name=include){,-fixed}

    ln -svr /usr/bin/cpp /usr/lib

    ln -sv gcc.1 /usr/share/man/man1/cc.1

    ln -sfvr $(gcc -print-prog-name=liblto_plugin.so) /usr/lib/bfd-plugins/

    echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
    readelf -l a.out | grep ': /lib'

    grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log

    grep -B4 '^ /usr/include' dummy.log

    grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'

    grep "/lib.*/libc.so.6 " dummy.log

    grep found dummy.log

    rm -v a.out dummy.log

    mkdir -pv /usr/share/gdb/auto-load/usr/lib
    mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

    cd "$SOURCES_DIR"
    rm -rf "gcc-16.2.0"
    log_info "Completed GCC-16.2.0 successfully!"
}

# Section 8.33: Ncurses-6.6
build_ncurses_6_6() {
    log_step "8.33" "Ncurses-6.6"
    cd "$SOURCES_DIR"
    if [ ! -f "ncurses-6.6.tar.gz" ]; then
        log_err "Tarball ncurses-6.6.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "ncurses-6.6"
    tar -xf "ncurses-6.6.tar.gz"
    cd "ncurses-6.6"

    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --with-shared           \
                --without-debug         \
                --without-normal        \
                --with-cxx-shared       \
                --enable-pc-files       \
                --with-pkg-config-libdir=/usr/lib/pkgconfig

    make

    make DESTDIR=$PWD/dest install
    sed -e 's/^#if.*XOPEN.*$/#if 1/' \
        -i dest/usr/include/curses.h
    cp --remove-destination -av dest/* /

    for lib in ncurses form panel menu ; do
        ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
    done

    ln -sfv libncursesw.so /usr/lib/libcurses.so

    cp -v -R doc -T /usr/share/doc/ncurses-6.6

    make distclean
    ./configure --prefix=/usr    \
                --with-shared    \
                --without-normal \
                --without-debug  \
                --without-cxx-binding \
                --with-abi-version=5
    make sources libs
    cp -av lib/lib*.so.5* /usr/lib

    cd "$SOURCES_DIR"
    rm -rf "ncurses-6.6"
    log_info "Completed Ncurses-6.6 successfully!"
}

# Section 8.34: Sed-4.10
build_sed_4_10() {
    log_step "8.34" "Sed-4.10"
    cd "$SOURCES_DIR"
    if [ ! -f "sed-4.10.tar.xz" ]; then
        log_err "Tarball sed-4.10.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "sed-4.10"
    tar -xf "sed-4.10.tar.xz"
    cd "sed-4.10"

    ./configure --prefix=/usr

    make
    make html

    make install
    install -vDm644 doc/sed.html -t /usr/share/doc/sed-4.10

    cd "$SOURCES_DIR"
    rm -rf "sed-4.10"
    log_info "Completed Sed-4.10 successfully!"
}

# Section 8.35: Psmisc-23.7
build_psmisc_23_7() {
    log_step "8.35" "Psmisc-23.7"
    cd "$SOURCES_DIR"
    if [ ! -f "psmisc-23.7.tar.xz" ]; then
        log_err "Tarball psmisc-23.7.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "psmisc-23.7"
    tar -xf "psmisc-23.7.tar.xz"
    cd "psmisc-23.7"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "psmisc-23.7"
    log_info "Completed Psmisc-23.7 successfully!"
}

# Section 8.36: Gettext-1.0
build_gettext_1_0() {
    log_step "8.36" "Gettext-1.0"
    cd "$SOURCES_DIR"
    if [ ! -f "gettext-1.0.tar.xz" ]; then
        log_err "Tarball gettext-1.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "gettext-1.0"
    tar -xf "gettext-1.0.tar.xz"
    cd "gettext-1.0"

    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/gettext-1.0

    make

    make install
    chmod -v 0755 /usr/lib/preloadable_libintl.so

    cd "$SOURCES_DIR"
    rm -rf "gettext-1.0"
    log_info "Completed Gettext-1.0 successfully!"
}

# Section 8.37: Bison-3.8.2
build_bison_3_8_2() {
    log_step "8.37" "Bison-3.8.2"
    cd "$SOURCES_DIR"
    if [ ! -f "bison-3.8.2.tar.xz" ]; then
        log_err "Tarball bison-3.8.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "bison-3.8.2"
    tar -xf "bison-3.8.2.tar.xz"
    cd "bison-3.8.2"

    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "bison-3.8.2"
    log_info "Completed Bison-3.8.2 successfully!"
}

# Section 8.38: Grep-3.12
build_grep_3_12() {
    log_step "8.38" "Grep-3.12"
    cd "$SOURCES_DIR"
    if [ ! -f "grep-3.12.tar.xz" ]; then
        log_err "Tarball grep-3.12.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "grep-3.12"
    tar -xf "grep-3.12.tar.xz"
    cd "grep-3.12"

    sed -i "s/echo/#echo/" src/egrep.sh

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "grep-3.12"
    log_info "Completed Grep-3.12 successfully!"
}

# Section 8.39: Bash-5.3
build_bash_5_3() {
    log_step "8.39" "Bash-5.3"
    cd "$SOURCES_DIR"
    if [ ! -f "bash-5.3.tar.gz" ]; then
        log_err "Tarball bash-5.3.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "bash-5.3"
    tar -xf "bash-5.3.tar.gz"
    cd "bash-5.3"

    ./configure --prefix=/usr             \
                --without-bash-malloc     \
                --with-installed-readline \
                --docdir=/usr/share/doc/bash-5.3

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "bash-5.3"
    log_info "Completed Bash-5.3 successfully!"
}

# Section 8.40: Libtool-2.6.2
build_libtool_2_6_2() {
    log_step "8.40" "Libtool-2.6.2"
    cd "$SOURCES_DIR"
    if [ ! -f "libtool-2.6.2.tar.xz" ]; then
        log_err "Tarball libtool-2.6.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "libtool-2.6.2"
    tar -xf "libtool-2.6.2.tar.xz"
    cd "libtool-2.6.2"

    ./configure --prefix=/usr

    make

    make install

    rm -fv /usr/lib/libltdl.a

    cd "$SOURCES_DIR"
    rm -rf "libtool-2.6.2"
    log_info "Completed Libtool-2.6.2 successfully!"
}

# Section 8.41: GDBM-1.26
build_gdbm_1_26() {
    log_step "8.41" "GDBM-1.26"
    cd "$SOURCES_DIR"
    if [ ! -f "gdbm-1.26.tar.gz" ]; then
        log_err "Tarball gdbm-1.26.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "gdbm-1.26"
    tar -xf "gdbm-1.26.tar.gz"
    cd "gdbm-1.26"

    ./configure --prefix=/usr    \
                --disable-static \
                --enable-libgdbm-compat

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "gdbm-1.26"
    log_info "Completed GDBM-1.26 successfully!"
}

# Section 8.42: Gperf-3.3
build_gperf_3_3() {
    log_step "8.42" "Gperf-3.3"
    cd "$SOURCES_DIR"
    if [ ! -f "gperf-3.3.tar.gz" ]; then
        log_err "Tarball gperf-3.3.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "gperf-3.3"
    tar -xf "gperf-3.3.tar.gz"
    cd "gperf-3.3"

    ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "gperf-3.3"
    log_info "Completed Gperf-3.3 successfully!"
}

# Section 8.43: Expat-2.8.3
build_expat_2_8_3() {
    log_step "8.43" "Expat-2.8.3"
    cd "$SOURCES_DIR"
    if [ ! -f "expat-2.8.3.tar.xz" ]; then
        log_err "Tarball expat-2.8.3.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "expat-2.8.3"
    tar -xf "expat-2.8.3.tar.xz"
    cd "expat-2.8.3"

    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/expat-2.8.3

    make

    make install

    install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.8.3

    cd "$SOURCES_DIR"
    rm -rf "expat-2.8.3"
    log_info "Completed Expat-2.8.3 successfully!"
}

# Section 8.44: Inetutils-2.8
build_inetutils_2_8() {
    log_step "8.44" "Inetutils-2.8"
    cd "$SOURCES_DIR"
    if [ ! -f "inetutils-2.8.tar.gz" ]; then
        log_err "Tarball inetutils-2.8.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "inetutils-2.8"
    tar -xf "inetutils-2.8.tar.gz"
    cd "inetutils-2.8"

    sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c

    ./configure --prefix=/usr        \
                --bindir=/usr/bin    \
                --localstatedir=/var \
                --disable-logger     \
                --disable-whois      \
                --disable-rcp        \
                --disable-rexec      \
                --disable-rlogin     \
                --disable-rsh        \
                --disable-servers

    make

    make install

    mv -v /usr/{,s}bin/ifconfig

    cd "$SOURCES_DIR"
    rm -rf "inetutils-2.8"
    log_info "Completed Inetutils-2.8 successfully!"
}

# Section 8.45: Less-704
build_less_704() {
    log_step "8.45" "Less-704"
    cd "$SOURCES_DIR"
    if [ ! -f "less-704.tar.gz" ]; then
        log_err "Tarball less-704.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "less-704"
    tar -xf "less-704.tar.gz"
    cd "less-704"

    ./configure --prefix=/usr --sysconfdir=/etc

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "less-704"
    log_info "Completed Less-704 successfully!"
}

# Section 8.46: Perl-5.44.0
build_perl_5_44_0() {
    log_step "8.46" "Perl-5.44.0"
    cd "$SOURCES_DIR"
    if [ ! -f "perl-5.44.0.tar.xz" ]; then
        log_err "Tarball perl-5.44.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "perl-5.44.0"
    tar -xf "perl-5.44.0.tar.xz"
    cd "perl-5.44.0"

    export BUILD_ZLIB=False
    export BUILD_BZIP2=0

    sh Configure -des                                          \
                 -D prefix=/usr                                \
                 -D vendorprefix=/usr                          \
                 -D privlib=/usr/lib/perl5/5.44/core_perl      \
                 -D archlib=/usr/lib/perl5/5.44/core_perl      \
                 -D sitelib=/usr/lib/perl5/5.44/site_perl      \
                 -D sitearch=/usr/lib/perl5/5.44/site_perl     \
                 -D vendorlib=/usr/lib/perl5/5.44/vendor_perl  \
                 -D vendorarch=/usr/lib/perl5/5.44/vendor_perl \
                 -D man1dir=/usr/share/man/man1                \
                 -D man3dir=/usr/share/man/man3                \
                 -D pager="/usr/bin/less -isR"                 \
                 -D useshrplib                                 \
                 -D usethreads

    make

    make install
    unset BUILD_ZLIB BUILD_BZIP2

    cd "$SOURCES_DIR"
    rm -rf "perl-5.44.0"
    log_info "Completed Perl-5.44.0 successfully!"
}

# Section 8.47: Autoconf-2.73
build_autoconf_2_73() {
    log_step "8.47" "Autoconf-2.73"
    cd "$SOURCES_DIR"
    if [ ! -f "autoconf-2.73.tar.xz" ]; then
        log_err "Tarball autoconf-2.73.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "autoconf-2.73"
    tar -xf "autoconf-2.73.tar.xz"
    cd "autoconf-2.73"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "autoconf-2.73"
    log_info "Completed Autoconf-2.73 successfully!"
}

# Section 8.48: Automake-1.18.1
build_automake_1_18_1() {
    log_step "8.48" "Automake-1.18.1"
    cd "$SOURCES_DIR"
    if [ ! -f "automake-1.18.1.tar.xz" ]; then
        log_err "Tarball automake-1.18.1.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "automake-1.18.1"
    tar -xf "automake-1.18.1.tar.xz"
    cd "automake-1.18.1"

    ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "automake-1.18.1"
    log_info "Completed Automake-1.18.1 successfully!"
}

# Section 8.49: OpenSSL-4.0.1
build_openssl_4_0_1() {
    log_step "8.49" "OpenSSL-4.0.1"
    cd "$SOURCES_DIR"
    if [ ! -f "openssl-4.0.1.tar.gz" ]; then
        log_err "Tarball openssl-4.0.1.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "openssl-4.0.1"
    tar -xf "openssl-4.0.1.tar.gz"
    cd "openssl-4.0.1"

    ./config --prefix=/usr         \
             --openssldir=/etc/ssl \
             --libdir=lib          \
             shared                \
             zlib-dynamic

    make

    make INSTALL_LIBS= MANSUFFIX=ssl install

    mv -v /usr/share/doc/openssl /usr/share/doc/openssl-4.0.1

    cp -vfr doc/* /usr/share/doc/openssl-4.0.1

    cd "$SOURCES_DIR"
    rm -rf "openssl-4.0.1"
    log_info "Completed OpenSSL-4.0.1 successfully!"
}

# Section 8.50: Libelf from Elfutils-0.195
build_libelf_from_elfutils_0_195() {
    log_step "8.50" "Libelf from Elfutils-0.195"
    cd "$SOURCES_DIR"
    if [ ! -f "elfutils-0.195.tar.bz2" ]; then
        log_err "Tarball elfutils-0.195.tar.bz2 not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "elfutils-0.195"
    tar -xf "elfutils-0.195.tar.bz2"
    cd "elfutils-0.195"

    ./configure --prefix=/usr        \
                --disable-debuginfod \
                --enable-libdebuginfod=dummy

    make -C lib
    make -C libelf

    make -C libelf install
    install -vm644 config/libelf.pc /usr/lib/pkgconfig
    rm /usr/lib/libelf.a

    cd "$SOURCES_DIR"
    rm -rf "elfutils-0.195"
    log_info "Completed Libelf from Elfutils-0.195 successfully!"
}

# Section 8.51: Libffi-3.8.0
build_libffi_3_8_0() {
    log_step "8.51" "Libffi-3.8.0"
    cd "$SOURCES_DIR"
    if [ ! -f "libffi-3.8.0.tar.gz" ]; then
        log_err "Tarball libffi-3.8.0.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "libffi-3.8.0"
    tar -xf "libffi-3.8.0.tar.gz"
    cd "libffi-3.8.0"

    ./configure --prefix=/usr    \
                --disable-static \
                --with-gcc-arch=native

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "libffi-3.8.0"
    log_info "Completed Libffi-3.8.0 successfully!"
}

# Section 8.52: Sqlite-3530400
build_sqlite_3530400() {
    log_step "8.52" "Sqlite-3530400"
    cd "$SOURCES_DIR"
    if [ ! -f "sqlite-autoconf-3530400.tar.gz" ]; then
        log_err "Tarball sqlite-autoconf-3530400.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "sqlite-autoconf-3530400"
    tar -xf "sqlite-autoconf-3530400.tar.gz"
    cd "sqlite-autoconf-3530400"

    python3 -m zipfile -e ../sqlite-doc-3530400.zip .

    ./configure --prefix=/usr     \
                --disable-static  \
                --enable-fts{4,5} \
                CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                          -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                          -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                          -D SQLITE_SECURE_DELETE=1"

    make LDFLAGS.rpath=""

    make install

    cp -v -R sqlite-doc-3530400 -T /usr/share/doc/sqlite-3.53.4

    cd "$SOURCES_DIR"
    rm -rf "sqlite-autoconf-3530400"
    log_info "Completed Sqlite-3530400 successfully!"
}

# Section 8.53: mpdecimal-4.0.1
build_mpdecimal_4_0_1() {
    log_step "8.53" "mpdecimal-4.0.1"
    cd "$SOURCES_DIR"
    if [ ! -f "mpdecimal-4.0.1.tar.gz" ]; then
        log_err "Tarball mpdecimal-4.0.1.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "mpdecimal-4.0.1"
    tar -xf "mpdecimal-4.0.1.tar.gz"
    cd "mpdecimal-4.0.1"

    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/mpdecimal-4.0.1

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "mpdecimal-4.0.1"
    log_info "Completed mpdecimal-4.0.1 successfully!"
}

# Section 8.54: Python-3.14.7
build_python_3_14_7() {
    log_step "8.54" "Python-3.14.7"
    cd "$SOURCES_DIR"
    if [ ! -f "Python-3.14.7.tar.xz" ]; then
        log_err "Tarball Python-3.14.7.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "Python-3.14.7"
    tar -xf "Python-3.14.7.tar.xz"
    cd "Python-3.14.7"

    patch -Np1 -i ../Python-3.14.7-openssl_4-1.patch

    ./configure --prefix=/usr          \
                --enable-shared        \
                --with-system-expat    \
                --enable-optimizations \
                --without-static-libpython

    make

    make install

    cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

    install -v -dm755 /usr/share/doc/python-3.14.7/html
    
    tar --strip-components=1  \
        --no-same-owner       \
        --no-same-permissions \
        -C /usr/share/doc/python-3.14.7/html \
        -xvf ../python-3.14.7-docs-html.tar.bz2

    cd "$SOURCES_DIR"
    rm -rf "Python-3.14.7"
    log_info "Completed Python-3.14.7 successfully!"
}

# Section 8.55: Flit-Core-4.0.2
build_flit_core_4_0_2() {
    log_step "8.55" "Flit-Core-4.0.2"
    cd "$SOURCES_DIR"
    if [ ! -f "flit_core-4.0.2.tar.gz" ]; then
        log_err "Tarball flit_core-4.0.2.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "flit_core-4.0.2"
    tar -xf "flit_core-4.0.2.tar.gz"
    cd "flit_core-4.0.2"

    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

    pip3 install --no-index --find-links dist flit_core

    cd "$SOURCES_DIR"
    rm -rf "flit_core-4.0.2"
    log_info "Completed Flit-Core-4.0.2 successfully!"
}

# Section 8.56: Packaging-26.3
build_packaging_26_3() {
    log_step "8.56" "Packaging-26.3"
    cd "$SOURCES_DIR"
    if [ ! -f "packaging-26.3.tar.gz" ]; then
        log_err "Tarball packaging-26.3.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "packaging-26.3"
    tar -xf "packaging-26.3.tar.gz"
    cd "packaging-26.3"

    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

    pip3 install --no-index --find-links dist packaging

    cd "$SOURCES_DIR"
    rm -rf "packaging-26.3"
    log_info "Completed Packaging-26.3 successfully!"
}

# Section 8.57: Wheel-0.48.0
build_wheel_0_48_0() {
    log_step "8.57" "Wheel-0.48.0"
    cd "$SOURCES_DIR"
    if [ ! -f "wheel-0.48.0.tar.gz" ]; then
        log_err "Tarball wheel-0.48.0.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "wheel-0.48.0"
    tar -xf "wheel-0.48.0.tar.gz"
    cd "wheel-0.48.0"

    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

    pip3 install --no-index --find-links dist wheel

    cd "$SOURCES_DIR"
    rm -rf "wheel-0.48.0"
    log_info "Completed Wheel-0.48.0 successfully!"
}

# Section 8.58: Setuptools-84.0.0
build_setuptools_84_0_0() {
    log_step "8.58" "Setuptools-84.0.0"
    cd "$SOURCES_DIR"
    if [ ! -f "setuptools-84.0.0.tar.gz" ]; then
        log_err "Tarball setuptools-84.0.0.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "setuptools-84.0.0"
    tar -xf "setuptools-84.0.0.tar.gz"
    cd "setuptools-84.0.0"

    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

    pip3 install --no-index --find-links dist setuptools

    cd "$SOURCES_DIR"
    rm -rf "setuptools-84.0.0"
    log_info "Completed Setuptools-84.0.0 successfully!"
}

# Section 8.59: Meson-1.12.0
build_meson_1_12_0() {
    log_step "8.59" "Meson-1.12.0"
    cd "$SOURCES_DIR"
    if [ ! -f "meson-1.12.0.tar.gz" ]; then
        log_err "Tarball meson-1.12.0.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "meson-1.12.0"
    tar -xf "meson-1.12.0.tar.gz"
    cd "meson-1.12.0"

    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

    pip3 install --no-index --find-links dist meson
    install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
    install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson

    cd "$SOURCES_DIR"
    rm -rf "meson-1.12.0"
    log_info "Completed Meson-1.12.0 successfully!"
}

# Section 8.60: Kmod-34.2
build_kmod_34_2() {
    log_step "8.60" "Kmod-34.2"
    cd "$SOURCES_DIR"
    if [ ! -f "kmod-34.2.tar.xz" ]; then
        log_err "Tarball kmod-34.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "kmod-34.2"
    tar -xf "kmod-34.2.tar.xz"
    cd "kmod-34.2"

    mkdir -p build
    cd       build
    
    meson setup --prefix=/usr ..    \
                --buildtype=release \
                -D manpages=false

    ninja

    ninja install

    cd "$SOURCES_DIR"
    rm -rf "kmod-34.2"
    log_info "Completed Kmod-34.2 successfully!"
}

# Section 8.61: Coreutils-9.11
build_coreutils_9_11() {
    log_step "8.61" "Coreutils-9.11"
    cd "$SOURCES_DIR"
    if [ ! -f "coreutils-9.11.tar.xz" ]; then
        log_err "Tarball coreutils-9.11.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "coreutils-9.11"
    tar -xf "coreutils-9.11.tar.xz"
    cd "coreutils-9.11"

    patch -Np1 -i ../coreutils-9.11-i18n-1.patch

    autoreconf -fv
    automake -af
    FORCE_UNSAFE_CONFIGURE=1 ./configure \
                --prefix=/usr

    make
    
    make install

    mv -v /usr/bin/chroot /usr/sbin
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

    cd "$SOURCES_DIR"
    rm -rf "coreutils-9.11"
    log_info "Completed Coreutils-9.11 successfully!"
}

# Section 8.62: Diffutils-3.12
build_diffutils_3_12() {
    log_step "8.62" "Diffutils-3.12"
    cd "$SOURCES_DIR"
    if [ ! -f "diffutils-3.12.tar.xz" ]; then
        log_err "Tarball diffutils-3.12.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "diffutils-3.12"
    tar -xf "diffutils-3.12.tar.xz"
    cd "diffutils-3.12"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "diffutils-3.12"
    log_info "Completed Diffutils-3.12 successfully!"
}

# Section 8.63: Findutils-4.11.0
build_findutils_4_11_0() {
    log_step "8.63" "Findutils-4.11.0"
    cd "$SOURCES_DIR"
    if [ ! -f "findutils-4.11.0.tar.xz" ]; then
        log_err "Tarball findutils-4.11.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "findutils-4.11.0"
    tar -xf "findutils-4.11.0.tar.xz"
    cd "findutils-4.11.0"

    ./configure --prefix=/usr --localstatedir=/var/lib/locate

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "findutils-4.11.0"
    log_info "Completed Findutils-4.11.0 successfully!"
}

# Section 8.64: Groff-1.24.1
build_groff_1_24_1() {
    log_step "8.64" "Groff-1.24.1"
    cd "$SOURCES_DIR"
    if [ ! -f "groff-1.24.1.tar.gz" ]; then
        log_err "Tarball groff-1.24.1.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "groff-1.24.1"
    tar -xf "groff-1.24.1.tar.gz"
    cd "groff-1.24.1"

    PAGE=$GROFF_PAGE ./configure --prefix=/usr

    make -j1

    make install

    cd "$SOURCES_DIR"
    rm -rf "groff-1.24.1"
    log_info "Completed Groff-1.24.1 successfully!"
}

# Section 8.65: GRUB-2.14
build_grub_2_14() {
    log_step "8.65" "GRUB-2.14"
    cd "$SOURCES_DIR"
    if [ ! -f "grub-2.14.tar.xz" ]; then
        log_err "Tarball grub-2.14.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "grub-2.14"
    tar -xf "grub-2.14.tar.xz"
    cd "grub-2.14"

    unset {C,CPP,CXX,LD}FLAGS

    sed 's/--image-base/--nonexist-linker-option/' -i configure

    ./configure --prefix=/usr     \
                --sysconfdir=/etc \
                --disable-efiemu  \
                --disable-werror

    make

    make install

    make clean

    ./configure --prefix=/usr       \
                --sysconfdir=/etc   \
                --target=x86_64     \
                --with-platform=efi \
                --disable-efiemu    \
                --disable-werror

    make

    make install

    make clean

    ./configure --prefix=/usr       \
                --sysconfdir=/etc   \
                --target=i386       \
                --with-platform=efi \
                --disable-efiemu    \
                --disable-werror

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "grub-2.14"
    log_info "Completed GRUB-2.14 successfully!"
}

# Section 8.66: Gzip-1.14
build_gzip_1_14() {
    log_step "8.66" "Gzip-1.14"
    cd "$SOURCES_DIR"
    if [ ! -f "gzip-1.14.tar.xz" ]; then
        log_err "Tarball gzip-1.14.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "gzip-1.14"
    tar -xf "gzip-1.14.tar.xz"
    cd "gzip-1.14"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "gzip-1.14"
    log_info "Completed Gzip-1.14 successfully!"
}

# Section 8.67: IPRoute2-7.1.0
build_iproute2_7_1_0() {
    log_step "8.67" "IPRoute2-7.1.0"
    cd "$SOURCES_DIR"
    if [ ! -f "iproute2-7.1.0.tar.xz" ]; then
        log_err "Tarball iproute2-7.1.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "iproute2-7.1.0"
    tar -xf "iproute2-7.1.0.tar.xz"
    cd "iproute2-7.1.0"

    sed -i /ARPD/d Makefile
    rm -fv man/man8/arpd.8

    make NETNS_RUN_DIR=/run/netns

    make SBINDIR=/usr/sbin install

    install -vDm644 COPYING README* -t /usr/share/doc/iproute2-7.1.0

    cd "$SOURCES_DIR"
    rm -rf "iproute2-7.1.0"
    log_info "Completed IPRoute2-7.1.0 successfully!"
}

# Section 8.68: Kbd-2.10.0
build_kbd_2_10_0() {
    log_step "8.68" "Kbd-2.10.0"
    cd "$SOURCES_DIR"
    if [ ! -f "kbd-2.10.0.tar.xz" ]; then
        log_err "Tarball kbd-2.10.0.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "kbd-2.10.0"
    tar -xf "kbd-2.10.0.tar.xz"
    cd "kbd-2.10.0"

    patch -Np1 -i ../kbd-2.10.0-backspace-1.patch

    sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
    sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

    ./configure --prefix=/usr --disable-vlock

    make

    make install

    cp -R -v docs/doc -T /usr/share/doc/kbd-2.10.0

    cd "$SOURCES_DIR"
    rm -rf "kbd-2.10.0"
    log_info "Completed Kbd-2.10.0 successfully!"
}

# Section 8.69: Libpipeline-1.5.8
build_libpipeline_1_5_8() {
    log_step "8.69" "Libpipeline-1.5.8"
    cd "$SOURCES_DIR"
    if [ ! -f "libpipeline-1.5.8.tar.gz" ]; then
        log_err "Tarball libpipeline-1.5.8.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "libpipeline-1.5.8"
    tar -xf "libpipeline-1.5.8.tar.gz"
    cd "libpipeline-1.5.8"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "libpipeline-1.5.8"
    log_info "Completed Libpipeline-1.5.8 successfully!"
}

# Section 8.70: Make-4.4.1
build_make_4_4_1() {
    log_step "8.70" "Make-4.4.1"
    cd "$SOURCES_DIR"
    if [ ! -f "make-4.4.1.tar.gz" ]; then
        log_err "Tarball make-4.4.1.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "make-4.4.1"
    tar -xf "make-4.4.1.tar.gz"
    cd "make-4.4.1"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "make-4.4.1"
    log_info "Completed Make-4.4.1 successfully!"
}

# Section 8.71: Patch-2.8
build_patch_2_8() {
    log_step "8.71" "Patch-2.8"
    cd "$SOURCES_DIR"
    if [ ! -f "patch-2.8.tar.xz" ]; then
        log_err "Tarball patch-2.8.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "patch-2.8"
    tar -xf "patch-2.8.tar.xz"
    cd "patch-2.8"

    ./configure --prefix=/usr

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "patch-2.8"
    log_info "Completed Patch-2.8 successfully!"
}

# Section 8.72: Tar-1.35
build_tar_1_35() {
    log_step "8.72" "Tar-1.35"
    cd "$SOURCES_DIR"
    if [ ! -f "tar-1.35.tar.xz" ]; then
        log_err "Tarball tar-1.35.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "tar-1.35"
    tar -xf "tar-1.35.tar.xz"
    cd "tar-1.35"

    patch -Np1 -i ../tar-1.35-acl_fix-1.patch

    FORCE_UNSAFE_CONFIGURE=1  \
    ./configure --prefix=/usr

    make

    make install
    make -C doc install-html docdir=/usr/share/doc/tar-1.35

    cd "$SOURCES_DIR"
    rm -rf "tar-1.35"
    log_info "Completed Tar-1.35 successfully!"
}

# Section 8.73: Texinfo-7.3
build_texinfo_7_3() {
    log_step "8.73" "Texinfo-7.3"
    cd "$SOURCES_DIR"
    if [ ! -f "texinfo-7.3.tar.xz" ]; then
        log_err "Tarball texinfo-7.3.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "texinfo-7.3"
    tar -xf "texinfo-7.3.tar.xz"
    cd "texinfo-7.3"

    ./configure --prefix=/usr

    make

    make install

    make TEXMF=/usr/share/texmf install-tex

    pushd /usr/share/info
      rm -v dir
      for f in *
        do install-info $f dir 2>/dev/null
      done
    popd

    cd "$SOURCES_DIR"
    rm -rf "texinfo-7.3"
    log_info "Completed Texinfo-7.3 successfully!"
}

# Section 8.74: Vim-9.2.1025
build_vim_9_2_1025() {
    log_step "8.74" "Vim-9.2.1025"
    cd "$SOURCES_DIR"
    if [ ! -f "vim-9.2.1025.tar.gz" ]; then
        log_err "Tarball vim-9.2.1025.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "vim-9.2.1025"
    tar -xf "vim-9.2.1025.tar.gz"
    cd "vim-9.2.1025"

    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

    ./configure --prefix=/usr

    make

    su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" \
       &> vim-test.log

    make install

    ln -sv vim /usr/bin/vi
    for L in  /usr/share/man/{,*/}man1/vim.1; do
        ln -sv vim.1 $(dirname $L)/vi.1
    done

    ln -sv ../vim/vim92/doc /usr/share/doc/vim-9.2.1025

    cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF

    cd "$SOURCES_DIR"
    rm -rf "vim-9.2.1025"
    log_info "Completed Vim-9.2.1025 successfully!"
}

# Section 8.75: MarkupSafe-3.0.3
build_markupsafe_3_0_3() {
    log_step "8.75" "MarkupSafe-3.0.3"
    cd "$SOURCES_DIR"
    if [ ! -f "markupsafe-3.0.3.tar.gz" ]; then
        log_err "Tarball markupsafe-3.0.3.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "MarkupSafe-3.0.3"
    tar -xf "markupsafe-3.0.3.tar.gz"
    cd "MarkupSafe-3.0.3"

    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

    pip3 install --no-index --find-links dist Markupsafe

    cd "$SOURCES_DIR"
    rm -rf "MarkupSafe-3.0.3"
    log_info "Completed MarkupSafe-3.0.3 successfully!"
}

# Section 8.76: Jinja2-3.1.6
build_jinja2_3_1_6() {
    log_step "8.76" "Jinja2-3.1.6"
    cd "$SOURCES_DIR"
    if [ ! -f "jinja2-3.1.6.tar.gz" ]; then
        log_err "Tarball jinja2-3.1.6.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "jinja2-3.1.6"
    tar -xf "jinja2-3.1.6.tar.gz"
    cd "jinja2-3.1.6"

    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

    pip3 install --no-index --find-links dist Jinja2

    cd "$SOURCES_DIR"
    rm -rf "jinja2-3.1.6"
    log_info "Completed Jinja2-3.1.6 successfully!"
}

# Section 8.77: Systemd-261.2
build_systemd_261_2() {
    log_step "8.77" "Systemd-261.2"
    cd "$SOURCES_DIR"
    if [ ! -f "systemd-261.2.tar.gz" ]; then
        log_err "Tarball systemd-261.2.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "systemd-261.2"
    tar -xf "systemd-261.2.tar.gz"
    cd "systemd-261.2"

    sed -e 's/GROUP="render"/GROUP="video"/' \
        -e 's/GROUP="sgx", //'               \
        -i rules.d/50-udev-default.rules.in

    mkdir -p build
    cd       build
    
    meson setup ..                \
          --prefix=/usr           \
          --buildtype=release     \
          -D default-dnssec=no    \
          -D firstboot=false      \
          -D install-tests=false  \
          -D ldconfig=false       \
          -D sysusers=false       \
          -D rpmmacrosdir=no      \
          -D homed=disabled       \
          -D man=disabled         \
          -D mode=release         \
          -D pamconfdir=no        \
          -D dev-kvm-mode=0660    \
          -D nobody-group=nogroup \
          -D sysupdate=disabled   \
          -D ukify=disabled       \
          -D docdir=/usr/share/doc/systemd-261.2

    ninja

    ninja install

    tar -xf ../../systemd-man-pages-261.2.tar.xz \
        --no-same-owner --strip-components=1     \
        -C /usr/share/man

    systemd-machine-id-setup

    systemctl preset-all 2>/dev/null || true

    cd "$SOURCES_DIR"
    rm -rf "systemd-261.2"
    log_info "Completed Systemd-261.2 successfully!"
}

# Section 8.78: D-Bus-1.16.2
build_d_bus_1_16_2() {
    log_step "8.78" "D-Bus-1.16.2"
    cd "$SOURCES_DIR"
    if [ ! -f "dbus-1.16.2.tar.xz" ]; then
        log_err "Tarball dbus-1.16.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "dbus-1.16.2"
    tar -xf "dbus-1.16.2.tar.xz"
    cd "dbus-1.16.2"

    mkdir build
    cd    build
    
    meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..

    ninja

    ninja install

    ln -sfv /etc/machine-id /var/lib/dbus

    cd "$SOURCES_DIR"
    rm -rf "dbus-1.16.2"
    log_info "Completed D-Bus-1.16.2 successfully!"
}

# Section 8.79: Man-DB-2.13.1
build_man_db_2_13_1() {
    log_step "8.79" "Man-DB-2.13.1"
    cd "$SOURCES_DIR"
    if [ ! -f "man-db-2.13.1.tar.xz" ]; then
        log_err "Tarball man-db-2.13.1.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "man-db-2.13.1"
    tar -xf "man-db-2.13.1.tar.xz"
    cd "man-db-2.13.1"

    ./configure --prefix=/usr                         \
                --docdir=/usr/share/doc/man-db-2.13.1 \
                --sysconfdir=/etc                     \
                --disable-setuid                      \
                --enable-cache-owner=bin              \
                --with-browser=/usr/bin/lynx          \
                --with-vgrind=/usr/bin/vgrind         \
                --with-grap=/usr/bin/grap

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "man-db-2.13.1"
    log_info "Completed Man-DB-2.13.1 successfully!"
}

# Section 8.80: Procps-ng-4.0.7
build_procps_ng_4_0_7() {
    log_step "8.80" "Procps-ng-4.0.7"
    cd "$SOURCES_DIR"
    if [ ! -f "procps-ng-4.0.7.tar.xz" ]; then
        log_err "Tarball procps-ng-4.0.7.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "procps-ng-4.0.7"
    tar -xf "procps-ng-4.0.7.tar.xz"
    cd "procps-ng-4.0.7"

    ./configure --prefix=/usr                           \
                --docdir=/usr/share/doc/procps-ng-4.0.7 \
                --disable-static                        \
                --disable-kill                          \
                --enable-watch8bit                      \
                --with-systemd

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "procps-ng-4.0.7"
    log_info "Completed Procps-ng-4.0.7 successfully!"
}

# Section 8.81: Util-linux-2.42.2
build_util_linux_2_42_2() {
    log_step "8.81" "Util-linux-2.42.2"
    cd "$SOURCES_DIR"
    if [ ! -f "util-linux-2.42.2.tar.xz" ]; then
        log_err "Tarball util-linux-2.42.2.tar.xz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "util-linux-2.42.2"
    tar -xf "util-linux-2.42.2.tar.xz"
    cd "util-linux-2.42.2"

    ./configure --bindir=/usr/bin     \
                --libdir=/usr/lib     \
                --runstatedir=/run    \
                --sbindir=/usr/sbin   \
                --disable-chfn-chsh   \
                --disable-login       \
                --disable-nologin     \
                --disable-su          \
                --disable-setpriv     \
                --disable-runuser     \
                --disable-pylibmount  \
                --disable-liblastlog2 \
                --disable-static      \
                --without-python      \
                ADJTIME_PATH=/var/lib/hwclock/adjtime \
                --docdir=/usr/share/doc/util-linux-2.42.2

    make

    make install

    cd "$SOURCES_DIR"
    rm -rf "util-linux-2.42.2"
    log_info "Completed Util-linux-2.42.2 successfully!"
}

# Section 8.82: E2fsprogs-1.47.4
build_e2fsprogs_1_47_4() {
    log_step "8.82" "E2fsprogs-1.47.4"
    cd "$SOURCES_DIR"
    if [ ! -f "e2fsprogs-1.47.4.tar.gz" ]; then
        log_err "Tarball e2fsprogs-1.47.4.tar.gz not found in $SOURCES_DIR!"
        return 1
    fi
    rm -rf "e2fsprogs-1.47.4"
    tar -xf "e2fsprogs-1.47.4.tar.gz"
    cd "e2fsprogs-1.47.4"

    mkdir -v build
    cd       build

    ../configure --prefix=/usr       \
                 --sysconfdir=/etc   \
                 --enable-elf-shlibs \
                 --disable-libblkid  \
                 --disable-libuuid   \
                 --disable-uuidd     \
                 --disable-fsck

    make

    make install

    rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

    gunzip -v /usr/share/info/libext2fs.info.gz
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

    makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
    install -v -m644 doc/com_err.info /usr/share/info
    install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info

    sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf

    cd "$SOURCES_DIR"
    rm -rf "e2fsprogs-1.47.4"
    log_info "Completed E2fsprogs-1.47.4 successfully!"
}

# Section 8.84: Stripping
do_stripping() {
    log_step "8.84" "Stripping Debugging Symbols"
    cd /usr/lib
    save_usrlib="$(cd /usr/lib; ls ld-linux*[^g] 2>/dev/null || true)
                 libc.so.6
                 libthread_db.so.1
                 libquadmath.so.0.0.0
                 libstdc++.so.6.0.36
                 libitm.so.1.0.0
                 libatomic.so.1.2.0"

    for LIB in $save_usrlib; do
        if [ -f "$LIB" ]; then
            objcopy --only-keep-debug --compress-debug-sections=zstd "$LIB" "$LIB.dbg" 2>/dev/null || true
            cp "$LIB" /tmp/"$LIB"
            strip --strip-unneeded /tmp/"$LIB" 2>/dev/null || true
            objcopy --add-gnu-debuglink="$LIB.dbg" /tmp/"$LIB" 2>/dev/null || true
            install -vm755 /tmp/"$LIB" /usr/lib
            rm -f /tmp/"$LIB"
        fi
    done

    online_usrbin="bash find strip"
    online_usrlib="libbfd-2.47.20260726.so
                   libsframe.so.3.0.0
                   libhistory.so.8.3
                   libncursesw.so.6.6
                   libm.so.6
                   libreadline.so.8.3
                   libz.so.1.3.2
                   libzstd.so.1.5.7
                   $(cd /usr/lib; find libnss*.so* -type f 2>/dev/null || true)"

    for BIN in $online_usrbin; do
        if [ -f "/usr/bin/$BIN" ]; then
            cp "/usr/bin/$BIN" "/tmp/$BIN"
            strip --strip-unneeded "/tmp/$BIN" 2>/dev/null || true
            install -vm755 "/tmp/$BIN" /usr/bin
            rm -f "/tmp/$BIN"
        fi
    done

    for LIB in $online_usrlib; do
        if [ -f "/usr/lib/$LIB" ]; then
            cp "/usr/lib/$LIB" "/tmp/$LIB"
            strip --strip-unneeded "/tmp/$LIB" 2>/dev/null || true
            install -vm755 "/tmp/$LIB" /usr/lib
            rm -f "/tmp/$LIB"
        fi
    done

    for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg 2>/dev/null) \
             $(find /usr/lib -type f -name \*.a 2>/dev/null)                 \
             $(find /usr/{bin,sbin,libexec} -type f 2>/dev/null); do
        case "$online_usrbin $online_usrlib $save_usrlib" in
            *$(basename "$i")* )
                ;;
            * ) strip --strip-unneeded "$i" 2>/dev/null || true
                ;;
        esac
    done

    unset BIN LIB save_usrlib online_usrbin online_usrlib
    log_info "Stripping completed successfully!"
}

# Section 8.85: Cleaning Up
do_cleanup() {
    log_step "8.85" "Cleaning Up Extra Files"
    rm -rf /tmp/{*,.*} 2>/dev/null || true
    find /usr/lib /usr/libexec -name \*.la -delete 2>/dev/null || true
    find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf 2>/dev/null || true
    userdel -r tester 2>/dev/null || true
    log_info "Cleanup completed successfully!"
}

# ------------------------------------------------------------------------------
# Package List & Main Runner
# ------------------------------------------------------------------------------
PACKAGES=(
    "8.3:build_man_pages_6_18:Man-pages-6.18"
    "8.4:build_iana_etc_20260805:Iana-Etc-20260805"
    "8.5:build_glibc_2_44:Glibc-2.44"
    "8.6:build_zlib_1_3_2:Zlib-1.3.2"
    "8.7:build_bzip2_1_0_8:Bzip2-1.0.8"
    "8.8:build_xz_5_8_3:Xz-5.8.3"
    "8.9:build_lz4_1_10_0:Lz4-1.10.0"
    "8.10:build_zstd_1_5_7:Zstd-1.5.7"
    "8.11:build_file_5_48:File-5.48"
    "8.12:build_readline_8_3:Readline-8.3"
    "8.13:build_pcre2_10_47:Pcre2-10.47"
    "8.14:build_m4_1_4_21:M4-1.4.21"
    "8.15:build_bc_7_0_3:Bc-7.0.3"
    "8.16:build_flex_2_6_4:Flex-2.6.4"
    "8.17:build_tcl_8_6_18:Tcl-8.6.18"
    "8.18:build_expect_5_45_4:Expect-5.45.4"
    "8.19:build_dejagnu_1_6_3:DejaGNU-1.6.3"
    "8.20:build_ninja_1_13_2:Ninja-1.13.2"
    "8.21:build_pkgconf_3_0_5:Pkgconf-3.0.5"
    "8.22:build_binutils_2_47:Binutils-2.47"
    "8.23:build_gmp_6_3_0:GMP-6.3.0"
    "8.24:build_mpfr_4_2_2:MPFR-4.2.2"
    "8.25:build_mpc_1_4_1:MPC-1.4.1"
    "8.26:build_attr_2_6_0:Attr-2.6.0"
    "8.27:build_acl_2_4_0:Acl-2.4.0"
    "8.28:build_libcap_2_78:Libcap-2.78"
    "8.29:build_libxcrypt_4_5_2:Libxcrypt-4.5.2"
    "8.30:build_shadow_4_20_2:Shadow-4.20.2"
    "8.31:build_gawk_5_4_1:Gawk-5.4.1"
    "8.32:build_gcc_16_2_0:GCC-16.2.0"
    "8.33:build_ncurses_6_6:Ncurses-6.6"
    "8.34:build_sed_4_10:Sed-4.10"
    "8.35:build_psmisc_23_7:Psmisc-23.7"
    "8.36:build_gettext_1_0:Gettext-1.0"
    "8.37:build_bison_3_8_2:Bison-3.8.2"
    "8.38:build_grep_3_12:Grep-3.12"
    "8.39:build_bash_5_3:Bash-5.3"
    "8.40:build_libtool_2_6_2:Libtool-2.6.2"
    "8.41:build_gdbm_1_26:GDBM-1.26"
    "8.42:build_gperf_3_3:Gperf-3.3"
    "8.43:build_expat_2_8_3:Expat-2.8.3"
    "8.44:build_inetutils_2_8:Inetutils-2.8"
    "8.45:build_less_704:Less-704"
    "8.46:build_perl_5_44_0:Perl-5.44.0"
    "8.47:build_autoconf_2_73:Autoconf-2.73"
    "8.48:build_automake_1_18_1:Automake-1.18.1"
    "8.49:build_openssl_4_0_1:OpenSSL-4.0.1"
    "8.50:build_libelf_from_elfutils_0_195:Libelf from Elfutils-0.195"
    "8.51:build_libffi_3_8_0:Libffi-3.8.0"
    "8.52:build_sqlite_3530400:Sqlite-3530400"
    "8.53:build_mpdecimal_4_0_1:mpdecimal-4.0.1"
    "8.54:build_python_3_14_7:Python-3.14.7"
    "8.55:build_flit_core_4_0_2:Flit-Core-4.0.2"
    "8.56:build_packaging_26_3:Packaging-26.3"
    "8.57:build_wheel_0_48_0:Wheel-0.48.0"
    "8.58:build_setuptools_84_0_0:Setuptools-84.0.0"
    "8.59:build_meson_1_12_0:Meson-1.12.0"
    "8.60:build_kmod_34_2:Kmod-34.2"
    "8.61:build_coreutils_9_11:Coreutils-9.11"
    "8.62:build_diffutils_3_12:Diffutils-3.12"
    "8.63:build_findutils_4_11_0:Findutils-4.11.0"
    "8.64:build_groff_1_24_1:Groff-1.24.1"
    "8.65:build_grub_2_14:GRUB-2.14"
    "8.66:build_gzip_1_14:Gzip-1.14"
    "8.67:build_iproute2_7_1_0:IPRoute2-7.1.0"
    "8.68:build_kbd_2_10_0:Kbd-2.10.0"
    "8.69:build_libpipeline_1_5_8:Libpipeline-1.5.8"
    "8.70:build_make_4_4_1:Make-4.4.1"
    "8.71:build_patch_2_8:Patch-2.8"
    "8.72:build_tar_1_35:Tar-1.35"
    "8.73:build_texinfo_7_3:Texinfo-7.3"
    "8.74:build_vim_9_2_1025:Vim-9.2.1025"
    "8.75:build_markupsafe_3_0_3:MarkupSafe-3.0.3"
    "8.76:build_jinja2_3_1_6:Jinja2-3.1.6"
    "8.77:build_systemd_261_2:Systemd-261.2"
    "8.78:build_d_bus_1_16_2:D-Bus-1.16.2"
    "8.79:build_man_db_2_13_1:Man-DB-2.13.1"
    "8.80:build_procps_ng_4_0_7:Procps-ng-4.0.7"
    "8.81:build_util_linux_2_42_2:Util-linux-2.42.2"
    "8.82:build_e2fsprogs_1_47_4:E2fsprogs-1.47.4"
    "8.84:do_stripping:Stripping"
    "8.85:do_cleanup:Cleaning Up"
)

main() {
    local start_from=""
    local run_only=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --start-from|-s)
                start_from="$2"
                shift 2
                ;;
            --only|-o)
                run_only="$2"
                shift 2
                ;;
            --delay|-d)
                SLEEP_INTERVAL="$2"
                shift 2
                ;;
            --list|-l)
                echo "Available packages in Chapter 8:"
                for item in "${PACKAGES[@]}"; do
                    IFS=":" read -r sec fn name <<< "$item"
                    printf "  %-6s %s\n" "$sec" "$name"
                done
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --start-from, -s <sec>   Start/resume from section (e.g. 8.32)"
                echo "  --only, -o <sec>         Build only specific section (e.g. 8.5)"
                echo "  --delay, -d <sec>        Delay between packages in seconds (default: 5)"
                echo "  --list, -l               List all packages"
                echo "  --help, -h               Show this help message"
                exit 0
                ;;
            *)
                log_err "Unknown argument: $1"
                exit 1
                ;;
        esac
    done

    check_environment

    local start_building=true
    if [ -n "$start_from" ]; then
        start_building=false
    fi

    local total_count="${#PACKAGES[@]}"
    local current_idx=0
    local t_start=$(date +%s)

    for item in "${PACKAGES[@]}"; do
        current_idx=$((current_idx + 1))
        IFS=":" read -r sec fn name <<< "$item"

        if [ -n "$run_only" ]; then
            if [ "$sec" != "$run_only" ]; then
                continue
            fi
        elif [ "$start_building" = false ]; then
            if [ "$sec" = "$start_from" ]; then
                start_building=true
            else
                continue
            fi
        fi

        echo -e "${YELLOW}[${current_idx}/${total_count}] Starting Section ${sec} (${name})...${RESET}"
        local pkg_start=$(date +%s)
        "$fn"
        local pkg_end=$(date +%s)
        local pkg_duration=$((pkg_end - pkg_start))
        echo -e "${GREEN}>>> Section ${sec} (${name}) completed in ${pkg_duration}s.${RESET}\n"

        if [ -n "$run_only" ]; then
            break
        fi

        if [ "$current_idx" -lt "$total_count" ] && [ "$SLEEP_INTERVAL" -gt 0 ]; then
            echo -e "${YELLOW}[INFO] Resting for ${SLEEP_INTERVAL}s before next package...${RESET}"
            sleep "$SLEEP_INTERVAL"
        fi
    done

    local t_end=$(date +%s)
    local total_duration=$((t_end - t_start))
    echo -e "\n${GREEN}==============================================================================${RESET}"
    echo -e "${GREEN}LFS Chapter 8 Installation Complete! Total time: $((total_duration / 60))m $((total_duration % 60))s.${RESET}"
    echo -e "${GREEN}==============================================================================${RESET}\n"
}

main "$@"
