module Result = struct
  include Stdlib.Result

  type ('a, 'e) or_msg = ('a, ([> `Msg of string | `Multi of 'e list ] as 'e)) t

  module Syntax = struct
    let ( let+ ) x f = Result.map f x
    let ( let* ) x f = Result.bind x f
    let ( >>= ) = Rresult.( >>= )
    let ( >>| ) = Rresult.( >>| )
  end

  let fold_list f lst acc =
    let rec loop acc errs = function
      | [] -> if errs = [] then Ok acc else Error (`Multi errs)
      | hd :: tl -> (
          match f acc hd with
          | Ok acc -> loop acc errs tl
          | Error err -> loop acc (err :: errs) tl)
    in
    loop acc [] lst

  let rec iter_until fn l =
    let open Syntax in
    match l with
    | hd :: tl -> fn hd >>= fun () -> iter_until fn tl
    | [] -> Ok ()
end
