--- TODO: consider creating a Quad class, or see if the love2D quad is suitable.

local function rectangleIntersection(rect1, rect2)
  return rect1.x < rect2.x + rect2.width and rect1.x + rect1.width > rect2.x and
      rect1.y < rect2.y + rect2.height and rect1.y + rect1.height > rect2.y
end


return {
  rectangleIntersection = rectangleIntersection
}
