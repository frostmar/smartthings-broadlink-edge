-- libraries
local log = require('log')

-- files
local config = require('config')
local disco = require('disco')
local broadlink = require('broadlink')

local lifecycle_handler = {}

function lifecycle_handler.init(driver, device)
  log.info('lifecycle_handler.init() entered for device with device_network_id='..device.device_network_id)

  if device.device_network_id:find("^BroadlinkRM_Virtual") then
    -- this is a virtual remote control device, no init needed
    log.info('lifecycle_handler.init() exiting')
    return
  end


  -- this must be a BroadlinkRM LAN device

  -- find the device's current IP

  if not driver._macaddr_to_ip[device.device_network_id] or not driver._macaddr_to_ip[device.device_network_id] then
    -- no cached info, broadcast to discover
    disco.do_discover(driver, nil)
  end

  local device_ip = driver._macaddr_to_ip[device.device_network_id]
  log.debug('using ip='..device_ip..' for device with macaddr='..device.device_network_id)
  device:set_field("ip", device_ip)
  local device_type = driver._macaddr_to_device_type[device.device_network_id]
  device:set_field("broadlink_device_type", device_type)

  broadlink.auth(device)

  -------------------
  -- Set up scheduled
  -- services once the
  -- driver gets
  -- initialized.

--   -- Ping schedule.
--   device.thread:call_on_schedule(
--     config.SCHEDULE_PERIOD,
--     function ()
--       return commands.ping(
--         driver.server.ip,
--         driver.server.port,
--         device)
--     end,
--     'Ping schedule')

--   -- Refresh schedule
--   device.thread:call_on_schedule(
--     config.SCHEDULE_PERIOD,
--     function ()
--       return commands.refresh(nil, device)
--     end,
--     'Refresh schedule')
  log.info('lifecycle_handler.init() exiting')
end

function lifecycle_handler.added(driver, device)
  log.info('lifecycle_handler.added() entered')
  -- Once device has been created
  -- at API level, poll its state
  -- via refresh command and send
  -- request to share server's ip
  -- and port to the device os it
  -- can communicate back.
--   commands.refresh(nil, device)
--   commands.ping(driver.server.ip, driver.server.port, device)
  log.info('lifecycle_handler.added() exiting')
end

function lifecycle_handler.removed(_, device)
  log.info('lifecycle_handler.removed() entered')
  -- Notify device that the device
  -- instance has been deleted and
  -- parent node must be deleted at
  -- device app.
--   commands.send_lan_command(
--     device.device_network_id,
--     'POST',
--     'delete')

  -- Remove Schedules created under
  -- device.thread to avoid unnecessary
  -- CPU processing.
  for timer in pairs(device.thread.timers) do
    device.thread:cancel_timer(timer)
  end

  log.info('lifecycle_handler.removed() exiting')
end

return lifecycle_handler