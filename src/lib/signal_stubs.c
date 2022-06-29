
#define CAML_NAME_SPACE
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>

#if defined(_WIN32) || defined(_WIN64)

#include <windows.h>
#include <stdio.h>

#else

#include <signal.h>

#endif

CAMLprim value ocaml_sigwinch(value unit)
{
  CAMLparam1(unit);
#ifdef SIGWINCH
  value result = caml_alloc_tuple(1);
  Field(result, 0) = Val_int(SIGWINCH);
  CAMLreturn(result);
#else
  CAMLreturn(Val_int(0));
#endif
}

