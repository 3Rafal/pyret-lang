#lang pyret

provide *

check:
  fun negate(f): fun(x): not(f(x)) end end
  fun around(n, delta): fun(other): num-abs(other - n) < delta;;

  num-max(1, 3) is 3
  num-max("not-a-num", 3) raises ""
  num-max(-1, -1) is -1
  num-max(-1, -2) is -1
  num-max(0.1, 1 / 11) is 0.1
  num-max(0, 1) is 1

  num-min(1, 3) is 1
  num-min("not-a-num", 3) raises ""
  num-min(-1, -1) is -1
  num-min(-1, -2) is -2
  num-min(0.1, 1 / 11) is 1 / 11
  num-min(0, 1) is 0

  1 / 10 is 0.1
  3 is 3
  # TODO(joe): Something is up with parsing bignums; these fail
  #3.000000000000000000000000000000000001 == 3 is false
  #1000000000000000000000000000000000000000000000000000000001
  #  == 1000000000000000000000000000000000000000000000000000000000
  #    is false
  #2.99999999999999999999999999999999999999999999 ==
  #  2.999999999999999999999999999999999999999999999
  #    is false
  # TODO(joe): WTF is up with the compilation of this next line?
  # 0.000000000000000000000001 * 100000000000000000000000 is 1

  num-abs(-1) is 1
  num-abs(-0.3) is 0.3
  num-abs(0) is 0
  num-abs(1) is 1

  # These are just sanity; the js-nums library has more rigorous tests
  # for the accuracy of the trig functions.  Here we just make sure the
  # Pyret functions are bound to plausible underlying operations
  num-sin(0) is 0
  num-sin(3.14 / 2) satisfies around(1, 0.1)
  num-sin(3.14) satisfies around(0, 0.1)

  num-cos(0) is 1
  num-cos(3.14 / 2) satisfies around(0, 0.1)
  num-cos(3.14) satisfies around(-1, 0.1)

  num-tan(0) is 0
  num-tan(3.14 / 4) satisfies around(1, 0.01)

  num-asin(0) is 0
  num-asin(1) satisfies around(1.57, 0.01)

  num-acos(0) satisfies around(1.57, 0.01)
  num-acos(1) is 0

  num-atan(0) is 0
  num-atan(1) satisfies around(0.78, 0.01)

  num-modulo(17, 5) is 2
  num-modulo(15, -2) is -1
  num-modulo(-17, -5) is -2
  num-modulo(-17, 5) is 3

  num-truncate(5.5) is 5
  num-truncate(-5.5) is -5

  num-sqrt(9) is 3
  num-sqrt(10) satisfies around(3.1, 0.1)
  num-sqrt(8768762532 * 8768762532) is 8768762532

  num-ceiling(5.5) is 6
  num-ceiling(5.1) is 6
  num-ceiling(-5.5) is -5

  num-floor(5.5) is 5
  num-floor(5.1) is 5
  num-floor(-5.5) is -6

  num-log(0) raises "expected a number greater than 0"
  num-log(1) is 0
  num-log(num-exp(1)) is 1

  2 is num-exact(2)
  1 / 3 is num-exact(1 / 3)
  # NOTE(joe): This seems a big algorithm-dependent; mainly here
  # as a regression test so we know if this changes
  num-exact(num-sqrt(2)) is 1767766952966369 / 1250000000000000

  2 satisfies num-is-integer
  1 / 3 satisfies negate(num-is-integer)
  num-sqrt(2) satisfies negate(num-is-integer)
  num-exp(3) satisfies negate(num-is-integer)
  num-log(1) satisfies num-is-integer

  num-expt(3, 2) is 9
  num-expt(2, -1) is 1 / 2
  num-expt(4, 1 / 2) is 2

  num-exp(3) satisfies around(20.08, 0.01)
  num-exp(1) satisfies around(2.71, 0.01)
  num-exp(0) is 1

end
