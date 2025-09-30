#!/bin/bash
set -ex

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* .

export PETSC_DIR=$SRC_DIR
export PETSC_ARCH=arch-conda-c-opt

if [[ $mpi == "openmpi" ]]; then
  export OMPI_CC=$CC
  export OPAL_PREFIX=$PREFIX
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  extra_opts="--with-batch"
fi

if [[ "${cuda_compiler_version}" != "None" ]]; then
  # CUDA in $PREFIX/targets/xxx
  cuda_dir=$PREFIX # cuda 12 and later
  # already providing ccbin in prepend flags
  cuda_c="--with-cudac=nvcc"
  if [[ "${target_platform}" == "linux-64" ]]; then
    export CUDA_CONDA_TARGET_NAME=x86_64-linux
  elif [[ "${target_platform}" == "linux-aarch64" ]]; then
    export CUDA_CONDA_TARGET_NAME=sbsa-linux
  elif [[ "${target_platform}" == "linux-ppc64le" ]]; then
    export CUDA_CONDA_TARGET_NAME=ppc64le-linux
  else
    echo "unexpected cuda target_platform=${target_platform}"
    exit 1
  fi
  export CUDA_CONDA_HOME=$cuda_dir
  cuda_incl=$cuda_dir/targets/${CUDA_CONDA_TARGET_NAME}/include
  cuda_libs="--with-cuda-lib=-lcudart -lcufft -lcublas -lcusparse -lcusolver -lcurand -lcuda"
  cuda_opts="--with-cuda=1 --with-cuda-include=$cuda_incl --with-cuda-arch=all-major"
else
  cuda_opts="--with-cuda=0"
fi

# unexport compiler variables to reduce warnings about config we know isn't used
# (This doesn't unset variables, just prevents the export for subprocesses)
export -n AR FC F90 F77 CC CXX CPP RANLIB
export -n CFLAGS CXXFLAGS CPPFLAGS FFLAGS LDFLAGS

if [[ "${scalar}" == "complex" ]]; then
  # conda-forge doesn't have complex hypre builds
  with_hypre="0"
else
  with_hypre="1"
fi

# petsc doesn't want us to set CFLAGS, etc.
# pass compiler flags via {C,CXX,F}OPTFLAGS to extend defaults
# instead of clobbering

python ./configure \
  AR="${AR:-ar}" \
  CPP="$CPP" \
  RANLIB="$RANLIB" \
  CC="mpicc" \
  CXX="mpicxx" \
  FC="mpifort" \
  CPPFLAGS="$CPPFLAGS" \
  LDFLAGS="$LDFLAGS" \
  --COPTFLAGS="$CFLAGS -O3" \
  --CXXOPTFLAGS="$CXXFLAGS -O3" \
  --FOPTFLAGS="$FFLAGS -O3" \
  --CUDAOPTFLAGS="-O3" \
  --with-clib-autodetect=0 \
  --with-cxxlib-autodetect=0 \
  --with-fortranlib-autodetect=0 \
  --with-debugging=0 \
  --with-blas-lib=libblas${SHLIB_EXT} \
  --with-lapack-lib=liblapack${SHLIB_EXT} \
  --with-yaml=1 \
  --with-hdf5=1 \
  --with-fftw=1 \
  --with-hwloc=1 \
  --with-openmp=1 \
  --with-hypre=${with_hypre} \
  --with-metis=1 \
  --with-mpi=1 \
  --with-mumps=1 \
  --with-parmetis=1 \
  --with-pthread=1 \
  --with-ptscotch=1 \
  --with-shared-libraries \
  --with-ssl=0 \
  --with-scalapack=1 \
  --with-superlu=1 \
  --with-superlu_dist=1 \
  --with-superlu_dist-include=$PREFIX/include/superlu-dist \
  --with-superlu_dist-lib=-lsuperlu_dist \
  --with-suitesparse=1 \
  --with-suitesparse-dir=$PREFIX \
  --with-x=0 \
  --with-scalar-type=${scalar} \
  "$cuda_c" \
  "$cuda_libs" \
  $cuda_opts \
  $extra_opts \
  --prefix=$PREFIX || (cat configure.log && exit 1)

# Verify that gcc_ext isn't linked
for f in $PETSC_ARCH/lib/petsc/conf/petscvariables $PETSC_ARCH/lib/pkgconfig/PETSc.pc; do
  if grep gcc_ext $f; then
    echo "gcc_ext found in $f"
    exit 1
  fi
done

sedinplace() {
  if [[ $(uname) == Darwin ]]; then
    sed -i "" "$@"
  else
    sed -i"" "$@"
  fi
}

# Remove abspath of ${BUILD_PREFIX}/bin/python
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/include/petscconf.h
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/lib/petsc/conf/petscvariables
sedinplace "s%${BUILD_PREFIX}/bin/python%/usr/bin/env python%g" $PETSC_ARCH/lib/petsc/conf/reconfigure-arch-conda-c-opt.py

# Replace abspath of ${PETSC_DIR} and ${BUILD_PREFIX} with ${PREFIX}
for path in $PETSC_DIR $BUILD_PREFIX; do
    for f in $(grep -l "${path}" $PETSC_ARCH/include/petsc*.h); do
        echo "Fixing ${path} in $f"
        grep "${path}" "$f"
        sedinplace s%${path}%\${PREFIX}%g $f
    done
done

make MAKE_NP=${CPU_COUNT}
make install

# Remove unneeded files
rm -f ${PREFIX}/lib/petsc/conf/configure-hash
find $PREFIX/lib/petsc -name '*.pyc' -delete

echo "#### unpatched petscvariables"
cat $PREFIX/lib/petsc/conf/petscvariables
echo "#### end unpatched petscvariables"

# remove abspath of executables in $BUILD_PREFIX
# let them resolve on $PATH
for f in $(grep -l "${BUILD_PREFIX}/bin/" -R "${PREFIX}/lib/petsc") "$PREFIX/lib/pkgconfig/PETSc.pc"; do
  echo "Fixing ${BUILD_PREFIX}/bin/ in $f"
  grep "${BUILD_PREFIX}/bin/" "$f" || true
  sedinplace s%${BUILD_PREFIX}/bin/%%g $f
done

# rewrite remaining $BUILD_PREFIX to $PREFIX
for f in $(grep -l "${BUILD_PREFIX}" -R "${PREFIX}/lib/petsc") "$PREFIX/lib/pkgconfig/PETSc.pc"; do
  echo "Fixing ${BUILD_PREFIX} in $f"
  grep "${BUILD_PREFIX}" "$f" || true
  sedinplace s%${BUILD_PREFIX}%${PREFIX}%g $f
done

echo "Removing example files"
du -hs $PREFIX/share/petsc/examples/src
rm -fr $PREFIX/share/petsc/examples/src
echo "Removing data files"
du -hs $PREFIX/share/petsc/datafiles/*
rm -fr $PREFIX/share/petsc/datafiles

echo "#### final petscvariables"
cat $PREFIX/lib/petsc/conf/petscvariables
echo "#### end final petscvariables"
