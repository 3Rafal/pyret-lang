provide *

import error as E

fun run-tests():
  check:
    fun get-err(thunk):
      cases(Either) run-task(thunk):
        | left(v) => "not-error"
        | right(v) => v
      end
    end

    "a" + "b" is "ab"
    4 + 5 is 9
    
    e1 = get-err(lam(): {} + "a";)
    e1 satisfies E.is-plus-error
    e1.val1 is {}
    e1.val2 is "a"

    o = {
        arr: [list: 1,2,3],
        _plus(self, other): for list.map2(a1 from self.arr, a2 from other.arr): a1 + a2;;
      }
    o2 = { arr: [list: 3,4,5] }
    (o + o2).arr is [list: 4,6,8]

  end
end
