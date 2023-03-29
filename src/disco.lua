-- libraries
local log = require('log')

-- files
local config = require('config')
local devicetypes = require('devicetypes')
local broadlink = require('broadlink')

-- This resource is linked to driver.discovery and is
-- automatically called when user scan devices from the
-- SmartThings App.

local disco = {}


local function create_device(driver, device_type, device_macaddr)
    log.info('entering create_device() for macaddr='..device_macaddr)
    local device_type_hex = ('0x%4x'):format(device_type)
    local device_model_name = devicetypes[device_type_hex]

    if device_model_name == nil then
        log.warn('NOT creating device - unrecognised device_type '.. device_type)
    else
        log.info('creating device '.. device_model_name)
        local metadata = {
            type = config.DEVICE_TYPE,
            device_network_id = device_macaddr,
            label = 'Broadlink Remote '..device_model_name,
            profile = config.DEVICE_PROFILE,
            manufacturer = 'Broadlink',
            model = device_model_name,
            vendor_provided_label = 'Broadlink IR Remote '..device_macaddr
        }
        return assert(driver:try_create_device(metadata), "failed to driver:try_create_device()")
    end
end

-- broadcast to discover devices on the network
-- populates driver._macaddr_to_ip{} and driver._macaddr_to_device_type{} as a side-effect
-- @param create_device_cb? nil|fun(driver: STDriver, device_type: string, device_macaddr: string) - optional callback to create new devices
function disco.do_discover(driver, create_device_cb)
    log.debug('disco.do_discover() entered')
    -- TODO: loop for multiple devices
    local device_res, device_ip = broadlink.broadcast_discovery()

    if device_res ~= nil then
      local device_type, device_macaddr = broadlink.parse_discovery_resp(device_res)
      log.info('DEVICE FOUND IN NETWORK: type='..('0x%4x'):format(device_type)..' macaddr='..device_macaddr)
      -- cache these values to use in init() later
      driver._macaddr_to_ip[device_macaddr] = device_ip
      driver._macaddr_to_device_type[device_macaddr] = device_type

      if create_device_cb ~= nil then
        local newdeviceid = create_device_cb(driver, device_type, device_macaddr)
        log.debug('disco.do_discover() exiting')
        return newdeviceid
      else
        log.debug('disco.do_discover() exiting')
        return
      end
    end

    log.warn('NO DEVICES FOUND IN NETWORK')
end

-- discover and create new devices
function disco.handle_discovery(driver, opts, cons)
    log.debug('disco.handle_discovery() entered')
    disco.do_discover(driver, create_device)
    log.debug('disco.start() exiting')
end


return disco