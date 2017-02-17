#!/bin/bash

export PETSC_DIR=$SRC_DIR
export PETSC_ARCH=arch-conda-c-opt


$PYTHON ./configure \
  LDFLAGS="$LDFLAGS" \
  --with-fc=0 \
  --with-debugging=0 \
  --COPTFLAGS=-O3 \
  --CXXOPTFLAGS=-O3 \
  --LIBS=-Wl,-rpath,$PREFIX/lib \
  --with-blas-lapack-lib=libopenblas${SHLIB_EXT} \
  --with-hwloc=0 \
  --with-mpi=1 \
  --with-mumps=1 \
  --with-pthread=1 \
  --with-ptscotch=1 \
  --with-scalapack=1 \
  --with-ssl=0 \
  --with-suitesparse=1 \
  --with-x=0 \
  --prefix=$PREFIX

sedinplace() { [[ $(uname) == Darwin ]] && sed -i "" $@ || sed -i"" $@; }
for path in $PETSC_DIR $PREFIX; do
    sedinplace s%$path%\${PETSC_DIR}%g $PETSC_ARCH/include/petsc*.h
done

make

if [[ $(uname) == Darwin ]]; then
    # FIXME: make check prevents upload on CircleCI
    # See https://github.com/conda-forge/conda-smithy/pull/337
    make check
fi

make install

rm -fr $PREFIX/bin
rm -fr $PREFIX/share
rm -fr $PREFIX/lib/lib$PKG_NAME.*.dylib.dSYM
rm -f  $PREFIX/lib/$PKG_NAME/conf/files
rm -f  $PREFIX/lib/$PKG_NAME/conf/*.py
rm -f  $PREFIX/lib/$PKG_NAME/conf/*.log
rm -f  $PREFIX/lib/$PKG_NAME/conf/RDict.db
rm -f  $PREFIX/lib/$PKG_NAME/conf/*BuildInternal.cmake
find   $PREFIX/include -name '*.html' -delete
