module Result = struct
  include Stdlib.Result

  type ('a, 'e) or_msg = ('a, ([> `Msg of string | `Multi of 'e list ] as 'e)) t

  module Syntax = struct
    let ( let+ ) x f = Result.map f x
    let ( let* ) x f = Result.bind x f
    let ( >>| ) x f = Result.map f x
    let ( >>= ) x f = Result.bind x f
  end

  module List = struct
    let fold_left :
        ('a -> 'b -> ('a, 'c) result) -> 'a -> 'b list -> ('a, 'c) or_msg =
     fun f acc lst ->
      let rec loop acc errs = function
        | [] -> if errs = [] then Ok acc else Error (`Multi errs)
        | hd :: tl -> (
            match f acc hd with
            | Ok acc -> loop acc errs tl
            | Error err -> loop acc (err :: errs) tl)
      in
      loop acc [] lst

    let filter_map :
        ('a -> ('b option, 'c) or_msg) -> 'a list -> ('b list, 'c) or_msg =
     fun f lst ->
      let open Syntax in
      let+ res =
        fold_left
          (fun acc e ->
            let+ o = f e in
            match o with Some a -> a :: acc | None -> acc)
          [] lst
      in
      List.rev res
  end

  let flatten = function
    | Ok (Ok e) -> Ok e
    | Ok (Error e) -> Error e
    | Error e -> Error e

  let errorf fmt = Format.kasprintf (fun msg -> Error (`Msg msg)) fmt
end

let with_tmp_dir suffix f =
  let f p () = f p in
  Bos.OS.Dir.with_tmp ("ocaml-platform-" ^^ suffix ^^ "-%s") f () |> Result.join
