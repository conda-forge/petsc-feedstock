#include <dlfcn.h>
#include <stdio.h>

int main(int argc,char **argv)
{
  void *handle;
  handle = dlopen("libpetsc.so", RTLD_GLOBAL | RTLD_NOW);
  if (!handle) {
    printf("%s\n",dlerror());
    return 1;
  }
  return dlclose(handle);
}
