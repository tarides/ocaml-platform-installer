val read_and_print :
  log_height:int option ->
  in_channel ->
  in_channel ->
  'a * ('a -> string -> 'a) * ('a -> 'b) ->
  'b * string list
