data Natural:
  | zero
  | succ(prev :: Natural)
end

data My-List<A>:
  | my-empty() # less clear what to do with non-thunk version
  | my-link(first :: A, rest :: My-List<A>)
end

fun<A> length(l :: My-List<A>) -> Natural:
  cases (My-List<A>) l:
    | my-empty()       => zero
    | my-link(_, rest) => succ(length(l))
  end
end
