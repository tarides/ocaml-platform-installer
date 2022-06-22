
#define CAML_NAME_SPACE
#include <caml/mlvalues.h>
#include <caml/alloc.h>

#if defined(_WIN32) || defined(_WIN64)

#include <windows.h>
#include <stdio.h>

CAMLprim value ocaml_sigwinch()
{
  return Val_int(0);
}

CAMLprim value ocaml_sigwinch (value unit)
{
  CAMLparam1 (unit);
  CAMLreturn (Val_int (SIGWINCH));
}

#else

#include <signal.h>

CAMLprim value ocaml_sigwinch()
{
#ifdef SIGWINCH
  value result = caml_alloc_tuple(1);
  Field(result, 0) = Val_int(SIGWINCH);
  return result;
#else
  return Val_int(0);
#endif
}

#endif
