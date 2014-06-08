#lang pyret

provide *
provide-types *

data Option:
  | none with:
    or-else(self, v :: Any):
      doc: "Return the default provided value"
      v
    end,
    and-then(self, _):
      doc: "Return none"
      self
    end
  | some(value) with:
    or-else(self, v :: Any):
      doc: "Return self.value, rather than the default"
      self.value
    end,
    and-then(self, f):
      doc: "Returns the function applied to self.value"
      f(self.value)
    end
where:
  none.or-else(1) is 1
  none.and-then(lam(x): x + 2 end) is none

  some(5).or-else(0) is 5
  some(5).and-then(lam(x): some(x + 2) end) is some(7)
end
