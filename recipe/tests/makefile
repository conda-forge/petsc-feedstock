include ${PETSC_DIR}/lib/petsc/conf/variables
include ${PETSC_DIR}/lib/petsc/conf/rules

testdlopen: testdlopen.o
	${CLINKER} -o testdlopen testdlopen.o -lpetsc -ldl
	${RM} testdlopen.o

ex1: ex1.o
	${CLINKER} -o ex1 ex1.o ${PETSC_LIB}
	${RM} ex1.o

ex1f: ex1f.o
	${FLINKER} -o ex1f ex1f.o ${PETSC_LIB}
	${RM} ex1f.o

runex1:
	${MPIEXEC} -n 1 ./ex1

runex1f:
	${MPIEXEC} -n 1 ./ex1f

include ${PETSC_DIR}/lib/petsc/conf/test
