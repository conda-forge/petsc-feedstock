program main
#include <petsc/finclude/petsc.h>
  use petsc

  PetscErrorCode ierr

  call PetscInitialize(PETSC_NULL_CHARACTER,ierr)
  call PetscFinalize(ierr)

end program main
