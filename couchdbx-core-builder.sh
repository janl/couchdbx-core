#!/bin/sh -ex
# CouchDBX-Core-Builder
# Downloads, Install Erlang & CouchDB into a package
# Copyright 2009 Jan Lehnardt <jan@apache.org>
# Apache 2.0 Licensed


# customise here:

# use full svn path for branches like "branches/0.9.x"
COUCHDB_VERSION="0.9.1"
COUCHDB_SVNPAPTH="tags/$COUCHDB_VERSION"

# or R12B-5
ERLANG_VERSION="R13B"

# make options
MAKE_OPTS="-j4"


# stop customizing

# internal vars
DIRS="src dist"
WORKDIR=`pwd`

# functions
erlang_download()
{
  if [ ! -e .erlang-downloaded ]; then
    FILE_NAME="otp_src_$ERLANG_VERSION"
    BASE_URL="http://www.csd.uu.se/ftp/mirror/erlang/download"
    cd src
    if [ ! -e $FILE_NAME.tar.gz ]; then
      curl -O $BASE_URL/$FILE_NAME.tar.gz
    fi
    tar xzf $FILE_NAME.tar.gz
    mv $FILE_NAME erlang
    cd ..
    touch .erlang-downloaded
  fi
}

erlang_install()
{
  if [ ! -e .erlang-installed ]; then
    cd src/erlang
    ./configure \
      --prefix=$WORKDIR/dist/erlang \
      --disable-hipe \
      --without-wxwidgets
    make # can't have -jN so no $MAKEOPTS
    make install
    cd ../../
    touch .erlang-installed
  fi
}

erlang_post_install()
{
  cd dist/erlang
  # change absolute paths to relative paths
  perl -pi -e "s@$WORKDIR/dist@\`pwd\`@" bin/erl
  # add quotes for paths with spaces
  perl -pi -e \
    's@`pwd`/erlang/lib/erlang@"`pwd`/erlang/lib/erlang"@' \
    bin/erl
  perl -pi -e 's@\$BINDIR/erlexec@"\$BINDIR/erlexec"@' bin/erl

  cd ../../
}

strip_erlang_dist()
{
  # strip unused erlang crap^Wlibs
  cd $WORKDIR/dist/erlang/lib/erlang/lib
  rm -rf \
    appmon-*/ \
    asn1-*/ \
    common_test-*/ \
    compiler-*/ \
    cosEvent-*/ \
    cosEventDomain-*/ \
    cosFileTransfer-*/ \
    cosNotification-*/ \
    cosProperty-*/ \
    cosTime-*/ \
    cosTransactions-*/ \
    debugger-*/ \
    dialyzer-*/ \
    docbuilder-*/ \
    edoc-*/ \
    erl_interface-*/ \
    erts-*/ \
    et-*/ \
    eunit-*/ \
    gs-*/ \
    hipe-*/ \
    ic-*/ \
    inviso-*/ \
    jinterface-*/ \
    megaco-*/ \
    mnesia-*/ \
    observer-*/ \
    odbc-*/ \
    orber-*/ \
    os_mon-*/ \
    otp_mibs-*/ \
    parsetools-*/ \
    percept-*/ \
    pman-*/ \
    public_key-*/ \
    reltool-*/ \
    runtime_tools-*/ \
    snmp-*/ \
    ssh-*/ \
    syntax_tools-*/ \
    test_server-*/ \
    toolbar-*/ \
    tools-*/ \
    tv-*/ \
    typer-*/ \
    webtool-*/ \
    wx-*/
    find . -name "src" | xargs rm -rf
    cd ../../../../../

    rm -f js/lib/libjs.a
    rm -rf js/bin
    rm -rf Darwin_DBG.OBJ
}

erlang()
{
  erlang_download
  erlang_install
}

couchdb_download()
{
  if [ ! -e .couchdb-downloaded ]; then
    cd src
    if [ ! -d couchdb ]; then
      svn export http://svn.apache.org/repos/asf/couchdb/$COUCHDB_SVNPAPTH couchdb
    fi
    cd ..
    touch .couchdb-downloaded
  fi
}

couchdb_install()
{
  if [ ! -e .couchdb-installed ]; then
    cd src/couchdb
    ./bootstrap
    export ERL=$WORKDIR/dist/erlang/bin/erl
    export ERLC=$WORKDIR/dist/erlang/bin/erlc
    ./configure \
      --prefix=$WORKDIR/dist/couchdb \
      --with-erlang=$WORKDIR/dist/erlang/lib/erlang/usr/include/ \
      --with-js-include=$WORKDIR/dist/js/include \
      --with-js-lib=$WORKDIR/dist/js/lib
    unset ERL_EXECUTABLE
    unset ERLC_EXECUTABLE

    make $MAKE_OPTS
    make install
    couchdb_post_install
    cd ../../
    touch .couchdb-installed
  fi
}

couchdb_link_erl_driver()
{
  cd src/couchdb
    gcc -I$WORKDIR/src/icu -I/usr/include -L/usr/lib \
        -I$WORKDIR/dist/erlang/lib/erlang/usr/include/ \
        -lpthread -lm -licucore \
        -flat_namespace -undefined suppress -bundle \
        -o couch_erl_driver.so couch_erl_driver.c -fPIC
    mv couch_erl_driver.so \
      ../../../../dist/couchdb/lib/couchdb/erlang/lib/couch-*/priv/lib
  cd ../../
}

couchdb_post_install()
{
  # build couch_erl_driver.so against bundlered ICU
  couchdb_link_erl_driver

  cd ../../dist/couchdb
  # replace absolute to relative paths
  perl -pi -e "s@$WORKDIR/dist/@@g" bin/couchdb bin/couchjs etc/couchdb/default.ini

  # remove icu-config call
  perl -pi -e "s@command=\"\`/usr/local/bin/icu-config --invoke\`@command=\"@" bin/couchdb
  cd ../../src/couchdb
}

couchdb()
{
  couchdb_download
  couchdb_install
}

create_dirs()
{
  mkdir -p $DIRS
}

cleanup()
{
  rm -rf $DIRS \
    .erlang-downloaded .erlang-installed \
    .couchdb-downloaded .couchdb-installed
}

download_icu()
{
  cd $WORKDIR/src/
  if [ ! -d icu ]; then
    svn export http://svn.webkit.org/repository/webkit/releases/Apple/Leopard/Mac%20OS%20X%2010.5/WebKit/icu/
  fi
  cd ../
}

download_js()
{
  if [ ! -e .js-downloaded ]; then
    cd src
    if [ ! -e js-1.7.0.tar.gz ]; then
      curl -O http://ftp.mozilla.org/pub/mozilla.org/js/js-1.7.0.tar.gz
    fi
    tar xzf js-1.7.0.tar.gz
    cd ..
    touch .js-downloaded
  fi
}

install_js()
{
  if [ ! -e .js-installed ]; then
    cd src/js
    cd src
    make $MAKEOPTS -f Makefile.ref
    JS_DIST=$WORKDIR/dist/js make -f Makefile.ref export
    cd ../../../
    mkdir dist/Darwin_DBG.OBJ/
    cp dist/js/lib/libjs.dylib dist/Darwin_DBG.OBJ/libjs.dylib
    touch .js-installed
  fi
}

js()
{
  download_js
  install_js
}


icu()
{
  download_icu  
}

package()
{
  rm -rf couchdbx-core
  mkdir couchdbx-core
  cp -r dist/* couchdbx-core
  tar czf couchdbx-core-$COCUHDB_VERSION-$ERLANG_VERSION.tar.gz couchdbx-core
}

# main:

create_dirs
erlang
icu
js
couchdb
erlang_post_install
strip_erlang_dist
package

echo "Done, kthxbye."
