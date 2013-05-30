#lang pyret


## NB(dbp): seals exist no longer

import "check.arr" as Check

todo1 = {
  due: "25 January 2012",
  task: "Write mixin examples",
  done: false,
  complete(self): self.{ done: true } end
}

fun sealable(obj):
  obj.{
    seal(self, names-to-expose):
      for list.fold(self-sealed from {}, name from names-to-expose):
        self-sealed.{ [name]: self.[name] }
      end
    end
  }
end

todo2 = sealable(todo1)
todo3 = todo2.seal(["done", "complete"])
Check.equal(todo3.done, false, "done is present after seal")
Check.equal(todo3.complete().done, true, "complete is present after seal")
todo3.task # should error
