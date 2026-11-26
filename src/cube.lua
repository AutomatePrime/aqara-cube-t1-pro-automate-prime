local cube = {}

function cube.rotation(angle)
  if type(angle) ~= "number" or angle ~= angle or math.abs(angle) == math.huge or angle == 0 then
    return
  end
  return angle > 0 and "clockwise" or "counterclockwise"
end

function cube.gesture(value)
  if type(value) ~= "number" or math.tointeger(value) == nil then return end
  if value == 0 then return "main" end
  if value >= 1024 and value <= 1029 then return "sceneFlip", value - 1023 end
  if value >= 512 and value <= 517 then return "doubleTap", value - 511 end
  if value >= 256 and value <= 261 then return "slide", value - 255 end
  if value >= 128 and value <= 133 then return "flip180", value - 127 end
  if value >= 64 and value <= 109 and value % 8 < 6 then
    return "flip90", value % 8 + 1, (value - 64) // 8 + 1
  end
end

-- Lumi heartbeat fields are a tag byte followed by a ZCL type and its payload.
function cube.heartbeat(payload)
  local fields = {}
  if type(payload) ~= "string" then return fields end
  local offset = 1
  while offset + 1 <= #payload do
    local tag, data_type = payload:byte(offset, offset + 1)
    offset = offset + 2
    local width
    if data_type == 0x00 then
      width = 0
    elseif data_type == 0x10 then
      width = 1
    elseif data_type >= 0x08 and data_type <= 0x0f then
      width = data_type - 0x07
    elseif data_type >= 0x18 and data_type <= 0x2f then
      width = (data_type & 7) + 1
    elseif data_type == 0x30 or data_type == 0x31 then
      width = data_type - 0x2f
    elseif data_type >= 0x38 and data_type <= 0x3a then
      width = 2 << (data_type - 0x38)
    else
      break
    end
    if offset + width - 1 > #payload then break end
    if tag == 1 and data_type == 0x21 then
      fields.millivolts = string.unpack("<I2", payload, offset)
    elseif tag == 155 and (data_type == 0x20 or data_type == 0x30) then
      fields.mode = payload:byte(offset)
    end
    offset = offset + width
  end
  return fields
end

return cube
