val read_and_print_ic :
  log_height:int option ->
  in_channel ->
  'a * ('a -> string -> 'a) * ('a -> 'b) ->
  'b
