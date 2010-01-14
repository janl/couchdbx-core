#!/bin/sh -ex
# CouchDBX-Core-Builder
# Downloads, Install Erlang & CouchDB into a package
# Copyright 2009 Jan Lehnardt <jan@apache.org>
# Apache 2.0 Licensed


# customise here:

# use full svn path for branches like "branches/0.9.x"
if [ -z "$COUCHDB_VERSION" ]; then
    COUCHDB_VERSION="0.10.1"
fi

if [ -z "$COUCHDB_SVNPATH" ]; then
    COUCHDB_SVNPATH="tags/0.10.1"
fi

# or R12B-5
if [ -z "$ERLANG_VERSION" ]; then
    ERLANG_VERSION="R13B03"
fi

# make options
MAKE_OPTS="-j4"


# stop customising

# internal vars
DIRS="src dist"
WORKDIR=`pwd`

ERLANGSRCDIR="erlang_$ERLANG_VERSION"
ERLANGDISTDIR="$ERLANGSRCDIR"

COUCHDBSRCDIR="couchdb_$COUCHDB_VERSION"
COUCHDBDISTDIR="$COUCHDBSRCDIR"

#functions
erlang_download()
{
  if [ ! -e .erlang-$ERLANG_VERSION-downloaded ]; then
    FILE_NAME="otp_src_$ERLANG_VERSION"
    BASE_URL="http://www.csd.uu.se/ftp/mirror/erlang/download"
    cd src
    if [ ! -e $FILE_NAME.tar.gz ]; then
      curl -O $BASE_URL/$FILE_NAME.tar.gz
    fi
    tar xzf $FILE_NAME.tar.gz
    mv $FILE_NAME $ERLANGSRCDIR
    cd ..
    touch .erlang-$ERLANG_VERSION-downloaded
  fi
}

erlang_install()
{
  if [ ! -e .erlang-$ERLANG_VERSION-installed ]; then
    cd src/$ERLANGSRCDIR
    ./configure \
      --prefix=$WORKDIR/dist/$ERLANGDISTDIR \
      --enable-hipe \
      --enable-dynamic-ssl-lib \
      --with-ssl=/usr \
      --without-java \
      --enable-darwin-64bit
    # skip wxWidgets
    touch lib/wx/SKIP
    make # can't have -jN so no $MAKEOPTS
    make install
    cd ../../
    cd dist
    rm -rf erlang
    cp -r $ERLANGDISTDIR erlang
    cd ..
    touch .erlang-$ERLANG_VERSION-installed
  fi
}

erlang_post_install()
{
  cd dist/$ERLANGDISTDIR
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

  # backup erlang build tree
  cp -r $WORKDIR/dist/$ERLANGDISTDIR $WORKDIR/dist/erlang

  # strip unused erlang crap^Wlibs
  cd $WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/lib
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
    cd src
    if [ ! -d "$COUCHDBSRCDIR" ]; then
      svn checkout http://svn.apache.org/repos/asf/couchdb/$COUCHDB_SVNPATH $COUCHDBSRCDIR
    fi
    cd ..
}

couchdb_install()
{
  # if [ ! -e .couchdb-installed ]; then
    cd src/$COUCHDBSRCDIR
    # PATH hack for jan's machine
    PATH=/usr/bin:$PATH ./bootstrap
    export ERLC_FLAGS="+native"
    export ERL=$WORKDIR/dist/$ERLANGDISTDIR/bin/erl
    export ERLC=$WORKDIR/dist/$ERLANGDISTDIR/bin/erlc
    ./configure \
      --prefix=$WORKDIR/dist/$COUCHDBDISTDIR \
      --with-erlang=$WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/usr/include/ \
      --with-js-include=$WORKDIR/dist/js/include \
      --with-js-lib=$WORKDIR/dist/js/lib
    unset ERL_EXECUTABLE
    unset ERLC_EXECUTABLE

    make $MAKE_OPTS
    make install
    couchdb_post_install
    cd ../../
  #   touch .couchdb-installed
  # fi
}

couchdb_link_erl_driver()
{

  if [ -d "src/couchdb/priv/icu_driver/" ]; then # we're on trunk
    cd src/couchdb/priv/icu_driver/
      gcc -I$WORKDIR/src/icu -I/usr/include -L/usr/lib \
          -I$WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/usr/include/ \
          -lpthread -lm -licucore \
          -flat_namespace -undefined suppress -bundle \
          -o couch_icu_driver.so couch_icu_driver.c -fPIC
      mv couch_icu_driver.so \
        ../../../../../../dist/$COUCHDBDISTDIR/lib/couchdb/erlang/lib/couch-*/priv/lib
      cd ../../../../
  else # we're on 0.10 or earlier
    cd src/couchdb
      gcc -I$WORKDIR/src/icu -I/usr/include -L/usr/lib \
          -I$WORKDIR/dist/$ERLANGDISTDIR/lib/erlang/usr/include/ \
          -lpthread -lm -licucore \
          -flat_namespace -undefined suppress -bundle \
          -o couch_erl_driver.so couch_erl_driver.c -fPIC
      mv couch_erl_driver.so \
        ../../../../dist/$COUCHDBDISTDIR/lib/couchdb/erlang/lib/couch-*/priv/lib
      cd ../../
  fi
}

couchdb_post_install()
{
  if [ "`uname`" = "Darwin" ]; then
    # build couch_erl_driver.so against bundled ICU
    couchdb_link_erl_driver
  fi

  cd ../../dist/$COUCHDBDISTDIR
  # replace absolute to relative paths
  perl -pi -e "s@$WORKDIR/dist/@@g" bin/couchdb bin/couchjs etc/couchdb/default.ini

  # remove icu-config call
  perl -pi -e "s@command=\"\`/usr/local/bin/icu-config --invoke\`@command=\"@" bin/couchdb
  cd ../../src/$COUCHDBSRCDIR
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
    uname=`uname`
    if [ "$uname" = "Darwin" ]; then
      soext="dylib"
    else
      soext="so"
    fi
    cd src/js
    cd src
    patch -N -p0 < ../../../patches/js/patch-jsprf.c
    make $MAKEOPTS -f Makefile.ref
    JS_DIST=$WORKDIR/dist/js make -f Makefile.ref export
    cd ../../../
    touch .js-installed
  fi
}

js()
{
  download_js
  install_js
}

package()
{
  PACKAGEDIR="couchdbx-core-$ERLANG_VERSION-$COUCHDB_VERSION"
  rm -rf $PACKAGEDIR
  mkdir $PACKAGEDIR
  cp -r dist/$ERLANGDISTDIR \
      dist/$COUCHDBDISTDIR \
      dist/js \
      $PACKAGEDIR
  install_name_tool -change Darwin_DBG.OBJ/libjs.dylib js/lib/libjs.dylib \
  $WORKDIR/dist/$COUCHDBSRCDIR/lib/couchdb/bin/couchjs
  cd $PACKAGEDIR
  ln -s $COUCHDBDISTDIR couchdb
  cd ..
  tar czf $PACKAGEDIR.tar.gz $PACKAGEDIR

  cd dist/
  rm -rf $ERLANGDISTDIR
  mv erlang $ERLANGDISTDIR
  cd ..
}

# main:

create_dirs
erlang
js
couchdb
erlang_post_install
strip_erlang_dist
package

echo "Done, kthxbye."
