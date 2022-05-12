module Result = struct
  include Result

  module Monad = struct
    let ( let+ ) x f = Result.map f x
    let ( let* ) x f = Result.bind x f
  end
end
