@echo on
setlocal EnableExtensions
set "OPENBLAS_NUM_THREADS=1"

if not defined PREFIX (
  echo PREFIX is not set
  exit /b 1
)

echo %PATH% | findstr /i /c:"cygwin" >nul
if not errorlevel 1 (
  echo Cygwin must not be present on the runtime PATH
  exit /b 1
)

set "PKG_CONFIG_PATH=%PREFIX%\Library\lib\pkgconfig"
set "CMAKE_PREFIX_PATH=%PREFIX%\Library"
set "TEST_SOURCE=%CD%\tests"
set "TEST_BUILD=%TEMP%\petsc-windows-test-%RANDOM%"
set "MPI_TEST_PATH=%PREFIX%\bin;%PREFIX%\Library\bin;%SystemRoot%\system32;%SystemRoot%"
set "MPI_OUTPUT=%TEST_BUILD%\mpi-output.txt"

if not exist "%TEST_SOURCE%\CMakeLists.txt" (
  echo Missing Windows package test sources: %TEST_SOURCE%
  exit /b 1
)
if not exist "%PREFIX%\Library\bin\libpetsc.dll" (
  echo Missing packaged PETSc DLL
  exit /b 1
)

pkg-config --validate PETSc
if errorlevel 1 exit /b 1
pkg-config --cflags PETSc >nul
if errorlevel 1 exit /b 1
pkg-config --libs PETSc >nul
if errorlevel 1 exit /b 1

cmake -S "%TEST_SOURCE%" -B "%TEST_BUILD%" -G Ninja -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl -DCMAKE_BUILD_TYPE=Release
if errorlevel 1 exit /b 1
cmake --build "%TEST_BUILD%" --config Release
if errorlevel 1 exit /b 1

"%TEST_BUILD%\ex1.exe"
if errorlevel 1 exit /b 1
rem Exercise PETSc's built-in direct solver through command-line options.
"%TEST_BUILD%\ex1.exe" -ksp_type preonly -pc_type lu -ksp_error_if_not_converged
if errorlevel 1 exit /b 1
"%TEST_BUILD%\ex1_cpp.exe"
if errorlevel 1 exit /b 1
mpiexec.exe -localonly -n 2 -env PATH "%MPI_TEST_PATH%" "%TEST_BUILD%\ex1.exe" > "%MPI_OUTPUT%" 2>&1
if errorlevel 1 exit /b 1
findstr /i /c:"KSP converged (reason" "%MPI_OUTPUT%" >nul
if errorlevel 1 exit /b 1

dumpbin /dependents "%TEST_BUILD%\ex1.exe" > "%TEST_BUILD%\ex1.dependents.txt"
if errorlevel 1 exit /b 1
findstr /i /c:"libpetsc.dll" "%TEST_BUILD%\ex1.dependents.txt" >nul
if errorlevel 1 exit /b 1
findstr /i /c:"cygwin1.dll" "%TEST_BUILD%\ex1.dependents.txt" >nul
if not errorlevel 1 exit /b 1

dumpbin /dependents "%PREFIX%\Library\bin\libpetsc.dll" > "%TEST_BUILD%\libpetsc.dependents.txt"
if errorlevel 1 exit /b 1
findstr /i /c:"impi.dll" "%TEST_BUILD%\libpetsc.dependents.txt" >nul
if errorlevel 1 exit /b 1
findstr /i /c:"openblas.dll" "%TEST_BUILD%\libpetsc.dependents.txt" >nul
if errorlevel 1 exit /b 1
findstr /i /c:"cygwin1.dll" "%TEST_BUILD%\libpetsc.dependents.txt" >nul
if not errorlevel 1 exit /b 1

python "%TEST_SOURCE%\check_metadata.py" "%PREFIX%"
if errorlevel 1 exit /b 1

echo Windows PETSc package interface, runtime, linkage, and metadata checks passed
endlocal
