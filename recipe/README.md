Windows builds use MSVC through PETSc's win32fe wrappers, conda-packaged MSYS2
build tools, Intel MPI, and pthreads OpenBLAS. They produce native Windows DLLs;
MSYS2 is only a build dependency. The Windows variant is CPU-only, real scalar,
double precision, with 32-bit indices. Fortran bindings and the optional solver,
HDF5, and FFTW integrations enabled on Unix are not included on Windows.

The initial Windows scripts and patches were adapted from precise-simulation's
PR https://github.com/conda-forge/petsc-feedstock/pull/291 for PETSc 3.26.1.
The Windows package tests compile C and C++ consumers through pkg-config/CMake,
solve a linear system in serial and on two MPI ranks, and check DLL dependencies
and installed metadata. The petsc.lib alias also supports setuptools consumers.

Configure uses a temporary directory inside the source work directory so native
Python and MSYS2 tools do not depend on runner-specific short-name temp paths or
a separate temporary drive. Configure failures print configure.log in CI.
