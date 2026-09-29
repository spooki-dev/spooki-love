local cacheManager = require "engine.cacheManager"
local Vector4 = require "engine.Vector4"

local renderer = {}

--- Draws a game object using its properties: pos, image, flipX, etc.
--- @param gameObject GameObject
function renderer.draw(gameObject)
  if (gameObject.renderLog) then
    print(gameObject.renderLog)
  end
  if not gameObject or not gameObject.active then return end -- Skip rendering if not active

  local pos = (gameObject.getPos and gameObject:getPos()) or { x = 0, y = 0 }
  local x = pos.x or pos[1] or 0
  local y = pos.y or pos[2] or 0

  local image, quad
  if gameObject.spritesheet and gameObject.quad then
    image = gameObject.spritesheet
    quad = gameObject.quad
  elseif gameObject.image then
    image = cacheManager.getImage(gameObject.image)
  end

  -- Apply positionOrigin as normalized (0-1) if present (for centering UI, etc)
  if gameObject.positionOrigin then
    local w = gameObject.width or (quad and quad:getWidth()) or (image and image:getWidth()) or 0
    local h = gameObject.height or (quad and quad:getHeight()) or (image and image:getHeight()) or 0
    x = x - (gameObject.positionOrigin.x or 0) * w
    y = y - (gameObject.positionOrigin.y or 0) * h
  end

  -- Draw fill rectangle if requested
  if gameObject.fillColor then
    local w = gameObject.width or 0
    local h = gameObject.height or 0
    local padding = gameObject.styles and gameObject.styles.padding or Vector4(0, 0, 0, 0)
    local borderRadius = gameObject.borderRadius or Vector4(0, 0, 0, 0)
    love.graphics.push()

    local r, g, b, a = gameObject.fillColor:unpack()
    love.graphics.setColor(r or 1, g or 1, b or 1, a or 1)
    if borderRadius.x + borderRadius.y + borderRadius.z + borderRadius.w > 0 then
      love.graphics.rectangle("fill", x, y, w, h + padding.z + padding.x,
        borderRadius.x, borderRadius.y, borderRadius.z, borderRadius.w)
    else
      love.graphics.rectangle("fill", x, y, w, h + padding.z + padding.x)
    end
    love.graphics.setColor(1, 1, 1, 1) -- reset color
    love.graphics.pop()                -- No need to draw image if fill is used
  end

  local padding = gameObject.styles and gameObject.styles.padding or Vector4(0, 0, 0, 0)
  local paddingY = padding.x + padding.z
  local paddingX = padding.y + padding.w

  if gameObject.debugPadding then
    -- Set color to the same green that chrome devtools uses for padding #B8C47F
    love.graphics.setColor(0.72, 0.77, 0.5, 0.3)

    -- Top padding
    if (padding.x > 0) then
      love.graphics.rectangle("fill", x, y,
        (gameObject.width or 0), padding.x)
    end
    -- Right padding
    if (padding.y > 0) then
      love.graphics.rectangle("fill", x + (gameObject.width or 0) - padding.y, y,
        padding.y, (gameObject.height or 0) + paddingY)
    end
    -- Bottom padding
    if (padding.z > 0) then
      love.graphics.rectangle("fill", x, y + (gameObject.height or 0) + padding.y,
        (gameObject.width or 0), padding.z)
    end
    -- Left padding
    if (padding.w > 0) then
      love.graphics.rectangle("fill", x, y,
        padding.w, (gameObject.height or 0) + paddingY)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  if gameObject.debugMargin then
    local margin = gameObject.styles and gameObject.styles.margin or Vector4(0, 0, 0, 0)
    --- Set color to orange with some transparency
    love.graphics.setColor(1, 0.5, 0, 0.3)
    if (margin.x > 0) then
      love.graphics.rectangle("fill", x, y - margin.x,
        (gameObject.width or 0), margin.x)
    end
    if (margin.y > 0) then
      love.graphics.rectangle("fill", x + (gameObject.width or 0), y,
        margin.y, (gameObject.height or 0))
    end
    if (margin.z > 0) then
      love.graphics.rectangle("fill", x, y + (gameObject.height or 0),
        (gameObject.width or 0), margin.z)
    end
    if (margin.w > 0) then
      love.graphics.rectangle("fill", x - margin.w, y,
        margin.w, (gameObject.height or 0))
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  if gameObject.debugBox then
    -- Draw bounding box #89B2BD
    love.graphics.setColor(0.54, 0.70, 0.74, 0.5)
    love.graphics.rectangle("fill", x + padding.w, y + padding.x,
      (gameObject.width or 0) - paddingX, (gameObject.height or 0))


    love.graphics.setColor(1, 1, 1, 1)
  end

  -- TODO draw gap debug lines
  if gameObject.debugGap then
    local gap = gameObject.styles and gameObject.styles.gap or 0

    -- Set color to same purple that chrome devtools uses for flex gap #9795E0
    if gap > 0 then
      love.graphics.setColor(0.59, 0.58, 0.88, 0.3)
      local flexDirection = gameObject.styles and gameObject.styles.flexDirection or "column"
      local stackYPos = y + padding.x
      for i, child in ipairs(gameObject.children or {}) do
        if flexDirection == "row" then
          -- Vertical gap line
          love.graphics.rectangle("fill",
            x + child.width,
            y,
            gap,
            gameObject.height or 0)
        else
          if i < #gameObject.children then
            stackYPos = stackYPos + child.height
            -- Horizontal gap line
            love.graphics.rectangle("fill",
              x,
              stackYPos,
              gameObject.width or 0,
              gap)

            stackYPos = stackYPos + gap
          end
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  if gameObject.text and gameObject.font then
    love.graphics.push()
    love.graphics.setFont(gameObject.font)
    love.graphics.setColor((gameObject.textColor or Vector4(1, 1, 1, 1)):unpack())
    love.graphics.printf(gameObject.text, pos.x, pos.y, gameObject.width, gameObject.textAlign or "left")
    love.graphics.pop()
  end

  --- TODO Implement border drawing for UI elements, border is a Vector4 (top, right, bottom, left)
  if gameObject.border then
    local r, g, b, a = (gameObject.borderColor or Vector4(1, 1, 1, 1)):unpack()
    love.graphics.setColor(r, g, b, a)
    local w = gameObject.width or 0
    local h = gameObject.height or 0
    local border = gameObject.border
    local padding = gameObject.styles and gameObject.styles.padding or Vector4(0, 0, 0, 0)
    local paddingY = padding.x + padding.z
    -- TODO: handle borderRadius border rendering
    local borderRadius = gameObject.borderRadius or Vector4(0, 0, 0, 0)

    if border.x + border.y + border.z + border.w == 0 then
      return
    end

    -- Top border
    if border.x > 0 then
      love.graphics.rectangle("fill", x, y, w, border.x)
    end
    -- Right border
    if border.y > 0 then
      love.graphics.rectangle("fill", x + w - border.y, y, border.y, h + paddingY)
    end
    -- Bottom border
    if border.z > 0 then
      love.graphics.rectangle("fill", x, y + h + paddingY - border.z, w, border.z)
    end
    -- Left border
    if border.w > 0 then
      love.graphics.rectangle("fill", x, y, border.w, h + paddingY)
    end
    love.graphics.setColor(1, 1, 1, 1) -- reset color
  end

  local image, quad
  if gameObject.spritesheet and gameObject.quad then
    image = gameObject.spritesheet
    quad = gameObject.quad
  elseif gameObject.image then
    image = cacheManager.getImage(gameObject.image)
  end

  if not image then return end

  local w = gameObject.width or (quad and quad:getWidth()) or image:getWidth()
  local h = gameObject.height or (quad and quad:getHeight()) or image:getHeight()
  -- Always scale/flip from center
  local centerX, centerY = w / 2, h / 2
  -- Custom origin for rotation only, but mirror vertically if flipY is set
  local rotOx, rotOy = centerX, centerY
  if gameObject.rotationOrigin then
    rotOx = gameObject.rotationOrigin.x
    if gameObject.flipY then
      rotOy = h - gameObject.rotationOrigin.y
    else
      rotOy = gameObject.rotationOrigin.y
    end
  end
  local scaleX = gameObject.flipX and -gameObject.scaleX or gameObject.scaleX
  local scaleY = (gameObject.flipY and -1 or 1) * gameObject.scaleY
  local rotation = gameObject.rotation or 0

  -- apply opacity if specified (set before drawing any tiles)
  if gameObject.opacity then
    love.graphics.setColor(1, 1, 1, gameObject.opacity)
  end


  -- To rotate around a custom origin but scale/flip from center, use transformation stack
  love.graphics.push()
  -- 1. Move to center for scaling/flipping
  love.graphics.translate(x + centerX, y + centerY)
  -- 2. Apply scaling/flipping
  love.graphics.scale(scaleX, scaleY)
  -- 3. Move back to top-left
  love.graphics.translate(-centerX, -centerY)
  -- 4. Move to rotation origin (relative to top-left)
  love.graphics.translate(rotOx, rotOy)
  -- 5. Rotate
  love.graphics.rotate(rotation)
  -- 6. Move back by rotation origin
  love.graphics.translate(-rotOx, -rotOy)
  -- 7. Draw at (0,0) since all transforms are applied


  -- To repeat the image or quad across the x or y
  local repeatX = gameObject.repeatX or 0
  local repeatY = gameObject.repeatY or 0
  local shouldRepeat = (repeatX > 0) or (repeatY > 0)
  if quad then
    if shouldRepeat then
      local totalW = repeatX > 0 and repeatX or w
      local totalH = repeatY > 0 and repeatY or h
      local _, _, tileW, tileH = quad:getViewport()
      local x = 0
      while x < totalW do
        local w = math.min(tileW, totalW - x)
        local y = 0
        while y < totalH do
          local h = math.min(tileH, totalH - y)
          if w < tileW or h < tileH then
            -- Draw a clipped quad for the last tile
            local qx, qy = quad:getViewport()
            local clippedQuad = love.graphics.newQuad(qx, qy, w, h, image:getDimensions())
            love.graphics.draw(image, clippedQuad, x, y)
          else
            love.graphics.draw(image, quad, x, y)
          end
          y = y + tileH
        end
        x = x + tileW
      end
    else
      love.graphics.draw(image, quad, 0, 0)
    end
  else
    if shouldRepeat then
      local totalW = repeatX > 0 and repeatX or w
      local totalH = repeatY > 0 and repeatY or h
      local tileW, tileH = image:getWidth(), image:getHeight()
      local x = 0
      while x < totalW do
        local w = math.min(tileW, totalW - x)
        local y = 0
        while y < totalH do
          local h = math.min(tileH, totalH - y)
          if w < tileW or h < tileH then
            love.graphics.setScissor(x, y, w, h)
            love.graphics.draw(image, x, y)
            love.graphics.setScissor()
          else
            love.graphics.draw(image, x, y)
          end
          y = y + tileH
        end
        x = x + tileW
      end
    else
      love.graphics.draw(image, 0, 0)
    end
  end
  love.graphics.pop()
  -- Reset color after drawing
  if gameObject.opacity then
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return renderer
