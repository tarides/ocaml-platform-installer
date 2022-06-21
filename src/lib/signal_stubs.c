#include <signal.h>
#define CAML_NAME_SPACE
#include <caml/mlvalues.h>
#include <caml/memory.h>

CAMLprim value ocaml_sigwinch (value unit)
{
  CAMLparam1 (unit);
  CAMLreturn (Val_int (SIGWINCH));
}
