#!/bin/sh -ex
# CouchDBX-Core-Builder
# Downloads, Install Erlang & CouchDB into a package
# Copyright 2009 Jan Lehnardt <jan@apache.org>
# Apache 2.0 Licensed


# customise here:

# use full svn path for branches like "branches/0.9.x"
COUCHDB_VERSION="trunk"

# or R12B-5
ERLANG_VERSION="R13A"

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
    erlang_post_install
    cd ../../
    touch .erlang-installed
  fi
}

erlang_post_install()
{
  # change absolute paths to relative paths
  perl -pi -e 's/$WORKDIR\/dist/`pwd`/' \
    bin/erl

  # strip unused erlang crap^Wlibs
  cd dist/erlang/lib/erlang/lib
  rm -rf \
    appmon-*/ \
    asn-*/ \
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
    dializer-*/ \
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
      svn export http://svn.apache.org/repos/asf/couchdb/$COUCHDB_VERSION couchdb
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
      --with-js-include=/usr/local/include --with-js-lib=/usr/local/lib
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
    gcc -I/usr/include -I/usr/lib \
        -I$WORKDIR/dist/erlang/lib/erlang/usr/include/ \
        -lpthread -lm -licucore \
        -flat_namespace -undefined suppress -bundle \
        -o couch_erl_driver.so couch_erl_driver.c -fPIC
    cp couch_erl_driver.so ../../../../dist/couchdb/
  cd ../../
}

couchdb_post_install()
{
  # build couch_erl_driver.so against bundlered ICU
  couchdb_link_erl_driver

  # replace absolute to relative paths
  perl -pi -e 's/$WORKDIR\/dist/`pwd`/' \
    bin/couchdb \
    etc/couchdb/default.ini
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

icu_download()
{
  cd src/
  if [ ! -d icu ]; then
    svn export http://svn.webkit.org/repository/webkit/releases/Apple/Leopard/Mac%20OS%20X%2010.5/WebKit/icu/
  fi
  cd ../
}

icu()
{
  icu_download
}

package()
{
  mkdir couchdbx-core
  cp -r dist/* couchdbx-core
  tar czf couchdbx-core.tar.gz couchdbx-core
}

# main:

create_dirs
erlang
icu
couchdb
package

echo "Done, kthxbye."
