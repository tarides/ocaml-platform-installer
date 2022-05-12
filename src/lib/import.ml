module Result = struct
  include Stdlib.Result

  module Syntax = struct
    let ( let+ ) x f = Result.map f x
    let ( let* ) x f = Result.bind x f
    let ( >>= ) = Rresult.( >>= )
    let ( >>| ) = Rresult.( >>| )
  end

  let rec iter_until fn l =
    let open Syntax in
    match l with
    | hd :: tl -> fn hd >>= fun () -> iter_until fn tl
    | [] -> Ok ()
end
