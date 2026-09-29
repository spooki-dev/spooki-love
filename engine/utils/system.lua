local function isWeb()
  return love.system.getOS and love.system.getOS() == "Web"
end

return {
  isWeb = isWeb
}
