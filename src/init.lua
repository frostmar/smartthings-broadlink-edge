-- inspired from:
--   https://community.smartthings.com/t/tutorial-creating-drivers-for-lan-devices-with-smartthings-edge/229501
--   https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/tree/main/drivers/SmartThings/samsung-audio/


-- libraries
local Driver = require('st.driver')
local capabilities = require('st.capabilities')
local log = require("log")
local st_utils = require("st.utils")
local socket = require("cosock.socket")

-- file imports
local disco = require('disco')
local lifecycles = require('lifecycles')
local broadlink = require('broadlink')


-- Custom capabilities
local capability_learnCode = capabilities["forgottenpeace60271.learnCode"]


-- file-scoped globals
local virtual_remote_device_counter = 0

---------------------------------------------------------------------------
-- handlers ---------------------------------------------------------------

-- create a new "Virtual IR Remote control"
local function create_new_device(driver, parent_device_id, counter)

  local MFG_NAME = 'SmartThings Community'
  local VEND_LABEL = string.format('Broadlink Virtual Remote Control #%d', counter)
  local MODEL = 'BroadlinkRM_Virtual'
  local ID = 'BroadlinkRM_Virtual_' .. socket.gettime()
  local PROFILE = 'BroadlinkRM-VirtualRemote-1btn.v1'

  log.debug (string.format('Creating virtual remote control device: label=<%s>, id=<%s>', VEND_LABEL, ID))

  local create_device_msg = {
                              type = "LAN",
                              parent_device_id = parent_device_id,
                              device_network_id = ID,
                              label = VEND_LABEL,
                              profile = PROFILE,
                              manufacturer = MFG_NAME,
                              model = MODEL,
                              vendor_provided_label = VEND_LABEL,
                            }

  assert (driver:try_create_device(create_device_msg), "failed to create virtual remote control device")
end

-- handler for all 'momentary' (button) capabilities
local function handle_momentary_button(driver, st_device, command)
    log.info ('Entered handle_momentary_button() command='..st_utils.stringify_table(command, nil, nil))
    log.info ('vendor_provided_label>'..st_device.vendor_provided_label:sub(20)..'<')

    if command.component == 'main' then
      if st_device.vendor_provided_label:sub(1, 20) == 'Broadlink IR Remote ' then
        -- this is a parent 'BroadlinkRM'
        broadlink.send_data(st_device.preferences.remoteCode, st_device)
      else
        -- this is a child 'virtual remote' button
        local parent_device = st_device:get_parent_device()
        log.debug ('got parent device OK')
        broadlink.send_data(st_device.preferences.remoteCode1, parent_device)
      end

    end

    if command.component == 'newVirtualRemoteDevice' then
      virtual_remote_device_counter = virtual_remote_device_counter + 1
      create_new_device(driver, st_device.id , virtual_remote_device_counter)
    end

end

-- handler for all 'switch' capabilities
local function handle_switch(driver, st_device, command)
  log.info ('Entered handle_switch() command='..st_utils.stringify_table(command, nil, nil))
  if command.command == 'on' then
    st_device:emit_event(capabilities.switch.switch('on'))
    handle_momentary_button(driver, st_device, command)
  end
  st_device:emit_event(capabilities.switch.switch('off'))
end

-- handler for custom 'learnCode' capability
local function handle_learn(driver, st_device, command)
  log.info ('Entered handle_learn() command='..st_utils.stringify_table(command, nil, nil))

  broadlink.enter_learning(st_device)

  st_device.thread:call_with_delay(1,
    function()
      broadlink.fetch_learned(st_device, 1)
    end
  )
end

---------------------------------------------------------------------------
-- Driver definition
local driver =
  Driver(
    'BroadlinkRM',
    {
      discovery = disco.handle_discovery,
      lifecycle_handlers = lifecycles,
      supported_capabilities = {
        capabilities.switch,
        -- capabilities.refresh
      },
      capability_handlers = {
        [capabilities.switch.ID] = {
          [capabilities.switch.commands.on.NAME] = handle_switch,
          [capabilities.switch.commands.off.NAME] = handle_switch,
        },
        [capabilities.momentary.ID] = {
          [capabilities.momentary.commands.push.NAME] = handle_momentary_button,
        },
        [capability_learnCode.ID] = {
          [capability_learnCode.commands.doLearn.NAME] = handle_learn,
        }
      },
      _macaddr_to_ip = {},         -- cache of Broadlink device mac address to IP, populated on a discovery broadcast
      _macaddr_to_device_type = {} -- cache of Broadlink device mac address to device-type, populated on a discovery broadcast
    }
  )


---------------------------------------------------------------------------
-- Initialize Driver
log.info("Start driver:run() BroadlinkRM driver")
driver:run()
log.warn("Exiting BroadlinkRM driver")