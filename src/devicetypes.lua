-- lookup of Broadlink device id to device name (IR Remotes only)
-- See:
--   https://github.com/mjg59/python-broadlink/blob/master/protocol.md#network-discovery
--   https://github.com/mjg59/python-broadlink/blob/master/broadlink/__init__.py

local devicetypes = {
    ['0x5f36'] = 'RM mini 3',
    ['0x6507'] = 'RM mini 3',
    ['0x6508'] = 'RM mini 3'
}

return devicetypes