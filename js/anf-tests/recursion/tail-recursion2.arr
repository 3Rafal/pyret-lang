
#lang pyret

fun f(n, so-far):
  if n > 1: f(n-1, n * so-far)
  else: so-far
  end
end

test-print(f(1000, 1))
test-print(f(2000, 1))
