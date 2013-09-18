#lang pyret

import "image2.arr" as image
import big-bang as bb
import math as Math
big-bang = bb.big-bang

List = list.List
link = list.link

width = 400
height = 100

init-world = []

ufo = image.circle(15, "solid", "red")

fun draw(w):
  fun draw-help(w2):
    cases (List) w2:
      | empty => image.rectangle(width * 3, height * 4, "solid", "white")
      | link(h, t) => draw-help(t).place-image(h.x, h.y, ufo)
    end
  end
  draw-help(w).to-image()
end

fun key(w, k):
  link({
      x: 
        (w.length() * ufo.width()) +
        (ufo.width() / 2) +
        2,
      y: width / 2 },
    w)
end

fun perturb(p):
  {x: p.x, y: p.y + (Math.random(9) - 4) }
end

fun tick(w):
  cases (List) w:
    | empty => w
    | link(f, r) => link(perturb(f), tick(r))
  end
end

big-bang(init-world,
  { on-key: key,
    to-draw: draw,
    on-tick: tick })
