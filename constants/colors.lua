local hexcolor = require "engine.utils.hexcolor"

local green = '#72751b'
local black = '#000000'
local dark = '#565a75'
local light = '#c6b7be'
local white = '#fafbf6'

local decimalBlack = hexcolor.hexToDecimalColor(black)
local decimalDark = hexcolor.hexToDecimalColor(dark)
local decimalLight = hexcolor.hexToDecimalColor(light)
local decimalWhite = hexcolor.hexToDecimalColor(white)
local decimalGreen = hexcolor.hexToDecimalColor(green)

local vec4Black = hexcolor.hexToVec4Color(black)
local vec4Dark = hexcolor.hexToVec4Color(dark)
local vec4Light = hexcolor.hexToVec4Color(light)
local vec4White = hexcolor.hexToVec4Color(white)
local vec4Green = hexcolor.hexToVec4Color(green)

return {
  black = decimalBlack,
  dark = decimalDark,
  light = decimalLight,
  white = decimalWhite,
  green = decimalGreen,
  vec4Black = vec4Black,
  vec4Dark = vec4Dark,
  vec4Light = vec4Light,
  vec4White = vec4White,
  vec4Green = vec4Green
}
