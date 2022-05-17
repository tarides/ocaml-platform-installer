module Result = struct
  include Stdlib.Result

  module Syntax = struct
    let ( let+ ) x f = Result.map f x
    let ( let* ) x f = Result.bind x f
  end
end
