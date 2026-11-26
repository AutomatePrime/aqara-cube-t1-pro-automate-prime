local ZigbeeDriver = require "st.zigbee"
local capabilities = require "st.capabilities"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local clusters = require "st.zigbee.zcl.clusters"
local PowerConfiguration = clusters.PowerConfiguration

local PRI_CLU = 0xFCC0
local PRI_ATTR = 0x0009
local MFG_CODE = 0x115F

local ROTATE_CLU = 0x000C
local EVENT_CLU = 0x0012
local FACE_ATTR = 0x0149
local ACTION_ATTR = 0x0055
local CUBE_MODE = 0x0148

local cubeAction = capabilities["concerttheme23846.cubeActionExtended"]
local decoder = require "cube"
local cubeFace = capabilities["stse.cubeFace"]
local cubeFaceVal = { "face1Up", "face2Up", "face3Up", "face4Up", "face5Up", "face6Up" }
local cubeFlipToSideVal = { "flipToSide1", "flipToSide2", "flipToSide3", "flipToSide4", "flipToSide5", "flipToSide6" }

local CUBEACTION_TIMER = "cubeAction_timer"
local CUBEACTION_TIME = 3

local callback_timer = function(device)
  return function()
    device:emit_event(cubeAction.action({value="No Action"}))
  end
end

local function reset_thread(device)
  local timer = device:get_field(CUBEACTION_TIMER)
  if timer then
    device.thread:cancel_timer(timer)
    device:set_field(CUBEACTION_TIMER, nil)
  end
  device:set_field(CUBEACTION_TIMER, device.thread:call_with_delay(CUBEACTION_TIME, callback_timer(device)))
end

local gestures = {
  main = { component = "shake", label = "Shake" },
  slide = { component = "slide", label = "Slide" },
  doubleTap = { component = "doubleTap", label = "Double Tap" },
  flip90 = { component = "flip90", label = "Flip 90 Degrees" },
  flip180 = { component = "flip180", label = "Flip 180 Degrees" },
  sceneFlip = { component = "sceneFlip", label = "Scene Flip" },
  clockwise = { component = "clockwise", label = "Rotate Clockwise" },
  counterclockwise = { component = "counterclockwise", label = "Rotate Counterclockwise" },
}

local function action(device, id)
  local gesture = gestures[id]
  if gesture == nil then return end

  device:emit_event(cubeAction.action({value=gesture.label}, {state_change=true}))
  local component = device.profile.components[gesture.component]
  if component then
    device:emit_component_event(component, capabilities.button.button.pushed({state_change=true}))
  end
end
local log = require "log"
local function request_mode(device)
  local mode = device:get_field("pending_mode")
  if mode == nil then return end
  local attempts = device:get_field("mode_attempts") or 0
  if attempts >= 3 then return end
  device:set_field("mode_attempts", attempts + 1)
  log.info("Sending Cube mode request " .. tostring(mode))
  device:send(cluster_base.write_manufacturer_specific_attribute(device, PRI_CLU, CUBE_MODE, MFG_CODE, data_types.Uint8, mode):to_endpoint(1))
end
local function mode_changed(_, device, _, args)
  local choice = device.preferences.modeRequest
  log.info("Cube preference: " .. tostring(choice))
  if ((args and args.old_st_store and args.old_st_store.preferences) or {}).modeRequest == choice then return end
  device:set_field("pending_mode", ({action=0,scene=1})[choice])
  device:set_field("mode_attempts", 0)
end
local function mode_report(_, device, attribute)
  if device:get_field("pending_mode") == attribute.value then device:set_field("pending_mode", nil) end
end
local function data_handler(driver, device, value, zb_rx)
  local id, face = decoder.gesture(value.value)
  if id == "sceneFlip" and device:get_field("pending_mode") == 1 or face and id ~= "sceneFlip" and device:get_field("pending_mode") == 0 then device:set_field("pending_mode", nil) end
  action(device, id)
  if face then device:emit_event(cubeFace.cubeFace(cubeFaceVal[face])) end
end
local function rotate_handler(driver, device, value, zb_rx)
  action(device, decoder.rotation(value.value))
end

local function face_handler(driver, device, value, zb_rx)
  local faceNum = value.value
  device:emit_event(cubeFace.cubeFace(cubeFaceVal[faceNum + 1]))
end

local function do_refresh(driver, device)
  -- refresh
  device:send(PowerConfiguration.attributes.BatteryVoltage:read(device))
end

local function device_init(driver, device)
  for _, gesture in pairs(gestures) do
    local component = device.profile.components[gesture.component]
    if component then
      device:emit_component_event(component, capabilities.button.supportedButtonValues({"pushed"}, {visibility={displayed=false}}))
      device:emit_component_event(component, capabilities.button.numberOfButtons(1, {visibility={displayed=false}}))
    end
  end
  device:set_field("pending_mode", ({action=0,scene=1})[device.preferences.modeRequest])
  device:set_field("mode_attempts", 0)
  local power_configuration = {
    cluster = PowerConfiguration.ID,
    attribute = PowerConfiguration.attributes.BatteryVoltage.ID,
    minimum_interval = 30,
    maximum_interval = 3600,
    data_type = PowerConfiguration.attributes.BatteryVoltage.base_type,
    reportable_change = 1
  }

  battery_defaults.build_linear_voltage_init(2.6, 3.0)(driver, device)

  device:add_configured_attribute(power_configuration)
  device:add_monitored_attribute(power_configuration)
end

local function device_added(self, device)
  -- Set private attribute
  device:send(cluster_base.write_manufacturer_specific_attribute(device,
    PRI_CLU, PRI_ATTR, MFG_CODE, data_types.Uint8, 1))

  device:emit_event(cubeAction.action({value="No Action"}))
  device:emit_event(cubeFace.cubeFace("face1Up"))
  do_refresh(self, device)
end

-- [[ register ]]
local aqara_cube_t1_pro_handler = {
  NAME = "Aqara Cube T1 Pro",
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh
    }
  },
  zigbee_handlers = {
    attr = {
      [EVENT_CLU] = {
        [ACTION_ATTR] = data_handler
      },
      [ROTATE_CLU] = {
        [ACTION_ATTR] = rotate_handler,
      },
      [PRI_CLU] = {
        [FACE_ATTR] = face_handler,
        [CUBE_MODE] = mode_report,
        [0x00F7] = function(_, device) request_mode(device) end
      },
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryVoltage.ID] = battery_defaults.battery_volt_attr_handler
      }
    }
  },
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    infoChanged = mode_changed
  },
  health_check = false,
}

local aqara_cube_t1_pro_driver = ZigbeeDriver("aqara_cube_t1_pro", aqara_cube_t1_pro_handler)
aqara_cube_t1_pro_driver:run()

