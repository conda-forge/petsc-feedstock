@echo on
copy "%RECIPE_DIR%\build_win.sh" .
set "PETSC_ALLOW_WIN32_PYTHON=1"
set "OPENBLAS_NUM_THREADS=1"
set "MSYSTEM=MSYS"
set "MSYS2_PATH_TYPE=inherit"
set "CHERE_INVOKING=1"
set "MSYS2_ARG_CONV_EXCL=*"
bash -lc "./build_win.sh"
if errorlevel 1 exit /b 1
exit /b 0
