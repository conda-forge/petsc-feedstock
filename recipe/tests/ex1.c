#include <petscksp.h>

int main(int argc,char **argv)
{
  Mat                 A;
  Vec                 exact, b, x;
  KSP                 ksp;
  PC                  pc;
  KSPConvergedReason  reason;
  PetscInt             n = 16, row, start, end, col;
  PetscReal            error;

  PetscCall(PetscInitialize(&argc, &argv, NULL, NULL));
  PetscCall(PetscOptionsGetInt(NULL, NULL, "-n", &n, NULL));
  PetscCheck(n > 0, PETSC_COMM_WORLD, PETSC_ERR_ARG_OUTOFRANGE, "-n must be positive");

  PetscCall(MatCreateAIJ(PETSC_COMM_WORLD, PETSC_DECIDE, PETSC_DECIDE, n, n, 3, NULL, 2, NULL, &A));
  PetscCall(MatGetOwnershipRange(A, &start, &end));
  for (row = start; row < end; ++row) {
    PetscScalar value;

    value = 2.0;
    PetscCall(MatSetValues(A, 1, &row, 1, &row, &value, INSERT_VALUES));
    value = -1.0;
    if (row > 0) {
      col = row - 1;
      PetscCall(MatSetValues(A, 1, &row, 1, &col, &value, INSERT_VALUES));
    }
    if (row + 1 < n) {
      col = row + 1;
      PetscCall(MatSetValues(A, 1, &row, 1, &col, &value, INSERT_VALUES));
    }
  }
  PetscCall(MatAssemblyBegin(A, MAT_FINAL_ASSEMBLY));
  PetscCall(MatAssemblyEnd(A, MAT_FINAL_ASSEMBLY));
  PetscCall(MatSetOption(A, MAT_SYMMETRIC, PETSC_TRUE));

  PetscCall(VecCreate(PETSC_COMM_WORLD, &exact));
  PetscCall(VecSetSizes(exact, PETSC_DECIDE, n));
  PetscCall(VecSetFromOptions(exact));
  PetscCall(VecDuplicate(exact, &b));
  PetscCall(VecDuplicate(exact, &x));
  PetscCall(VecSet(exact, 1.0));
  PetscCall(MatMult(A, exact, b));
  PetscCall(VecSet(x, 0.0));

  PetscCall(KSPCreate(PETSC_COMM_WORLD, &ksp));
  PetscCall(KSPSetOperators(ksp, A, A));
  PetscCall(KSPSetType(ksp, KSPCG));
  PetscCall(KSPGetPC(ksp, &pc));
  PetscCall(PCSetType(pc, PCJACOBI));
  PetscCall(KSPSetTolerances(ksp, 1e-12, PETSC_DEFAULT, PETSC_DEFAULT, PETSC_DEFAULT));
  PetscCall(KSPSetFromOptions(ksp));
  PetscCall(KSPSolve(ksp, b, x));
  PetscCall(KSPGetConvergedReason(ksp, &reason));
  PetscCheck(reason > 0, PETSC_COMM_WORLD, PETSC_ERR_NOT_CONVERGED, "KSP did not converge (reason %d)", (int)reason);

  PetscCall(VecAXPY(x, -1.0, exact));
  PetscCall(VecNorm(x, NORM_2, &error));
  PetscCheck(error < 1e-10, PETSC_COMM_WORLD, PETSC_ERR_PLIB, "KSP error norm %g exceeds 1e-10", (double)error);
  PetscCall(PetscPrintf(PETSC_COMM_WORLD, "KSP converged (reason %d), error norm %g\n", (int)reason, (double)error));

  PetscCall(KSPDestroy(&ksp));
  PetscCall(VecDestroy(&x));
  PetscCall(VecDestroy(&b));
  PetscCall(VecDestroy(&exact));
  PetscCall(MatDestroy(&A));
  PetscCall(PetscFinalize());
  return 0;
}
