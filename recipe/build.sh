#!/bin/bash
set -eu
export PETSC_DIR=$SRC_DIR
export PETSC_ARCH=arch-conda-c-opt

unset F90
unset F77
unset CC
unset CXX
if [[ $(uname) == Linux ]]; then
    export LDFLAGS="-pthread -fopenmp $LDFLAGS"
    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
    # --as-needed appears to cause problems with fortran compiler detection
    # due to missing libquadmath
    # unclear why required libs are stripped but still linked
    export FFLAGS="${FFLAGS:-} -Wl,--no-as-needed"
fi

# scrub debug-prefix-map args, which cause problems in pkg-config
export CFLAGS=$(echo ${CFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export FFLAGS=$(echo ${FFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')

if [[ $mpi == "openmpi" ]]; then
  export LIBS="-Wl,-rpath,$PREFIX/lib -lmpi_mpifh -lgfortran"
elif [[ $mpi == "mpich" ]]; then
  export LIBS="-lmpifort -lgfortran"
fi

python ./configure \
  AR="${AR:-ar}" \
  CC="mpicc" \
  CXX="mpicxx" \
  FC="mpifort" \
  CFLAGS="$CFLAGS" \
  CPPFLAGS="$CPPFLAGS" \
  CXXFLAGS="$CXXFLAGS" \
  FFLAGS="$FFLAGS" \
  LDFLAGS="$LDFLAGS" \
  LIBS="$LIBS" \
  --COPTFLAGS=-O3 \
  --CXXOPTFLAGS=-O3 \
  --FOPTFLAGS=-O3 \
  --with-clib-autodetect=0 \
  --with-cxxlib-autodetect=0 \
  --with-fortranlib-autodetect=0 \
  --with-debugging=0 \
  --with-blas-lib=libblas${SHLIB_EXT} \
  --with-lapack-lib=liblapack${SHLIB_EXT} \
  --with-hwloc=0 \
  --with-hypre=1 \
  --with-metis=1 \
  --with-mpi=1 \
  --with-mumps=1 \
  --with-parmetis=1 \
  --with-pthread=1 \
  --with-ptscotch=1 \
  --with-shared-libraries \
  --with-ssl=0 \
  --with-scalapack=1 \
  --with-suitesparse=1 \
  --with-x=0 \
  --prefix=$PREFIX || (cat configure.log && exit 1)

sedinplace() {
  if [[ $(uname) == Darwin ]]; then
    sed -i "" "$@"
  else
    sed -i"" "$@"
  fi
}

for path in $PETSC_DIR $PREFIX; do
    sedinplace s%$path%\${PETSC_DIR}%g $PETSC_ARCH/include/petsc*.h
done

# remove abspath of build_env/bin/python
sedinplace "s%${BUILD_PREFIX}/bin/python%/usr/bin/env python2%g" $PETSC_ARCH/lib/petsc/conf/reconfigure-arch-conda-c-opt.py
sedinplace "s%${BUILD_PREFIX}/bin/python%python2%g" $PETSC_ARCH/lib/petsc/conf/petscvariables

# verify that gcc_ext isn't linked
for f in lib/petsc/conf/petscvariables lib/pkgconfig/PETSc.pc; do
  if grep gcc_ext $f; then
    echo "gcc_ext found in $f"
    exit 1
  fi
done

make

for f in $(grep -l build_env -R "${PETSC_ARCH}/lib/petsc"); do
  echo "fixing build prefix in $f"
  sedinplace s%${BUILD_PREFIX}%${PREFIX}%g $f
done

# FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
# See https://github.com/conda-forge/conda-smithy/pull/337
# See https://github.com/pmodels/mpich/pull/2755
make check MPIEXEC="${RECIPE_DIR}/mpiexec.sh"

make install

rm -fr $PREFIX/share/petsc/examples
rm -fr $PREFIX/share/petsc/datafiles
find   $PREFIX/lib/petsc -name '*.pyc' -delete
