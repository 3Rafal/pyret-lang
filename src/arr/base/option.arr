#lang pyret

provide *
provide-types *

data Option:
  | none with:
    orelse(self, v :: Any):
      doc: "Return the default provided value"
      v
    end,
    andthen(self, _):
      doc: "Return none"
      self
    end
  | some(value) with:
    orelse(self, v :: Any):
      doc: "Return self.value, rather than the default"
      self.value
    end,
    andthen(self, f):
      doc: "Returns the function applied to self.value"
      f(self.value)
    end
where:
  none.orelse(1) is 1
  none.andthen(lam(x): x + 2 end) is none

  some(5).orelse(0) is 5
  some(5).andthen(lam(x): some(x + 2) end) is some(7)
end
