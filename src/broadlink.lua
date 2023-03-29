-- libraries
local log = require('log')
local socket = require('socket')
local os = require('os')
local capabilities = require('st.capabilities')
local st_base64 = require('st.base64')

local Array         = require "lockbox.util.array"
local Stream        = require "lockbox.util.stream"
local CBCMode       = require "lockbox.cipher.mode.cbc"
local ZeroPadding   = require "lockbox.padding.zero"
local AES128Cipher  = require "lockbox.cipher.aes128"

-- files
local config = require('config')

-- globals
local DISCOVER_ADDRESS='255.255.255.255'
local DISCOVER_PORT=80
local COMMAND_PORT=80

local broadlink = {}
local packet_counter=1

-- Custom capabilities
local capability_learnCode = capabilities["forgottenpeace60271.learnCode"]


-- @param  str string - bytes to show
-- @return string - hex display of the str bytes
local function printhex(str)
    local hex='\n'
    for i=1,#str,1 do
        hex = hex .. string.format('%02x ', str:byte(i))
        if i%4 == 0 then
            hex = hex .. ' '
        end
        if i%16 == 0 then
            hex = hex .. '\n'
        end
    end

    return hex
end

-- @return int - broadlink protocol data checksum
local function get_checksum(data)
    local checksum = 0xbeaf
    for i=1,#data do
        local byte = data:byte(i)
        checksum = checksum + byte
        checksum = checksum % 0xffff
    end
    return checksum
end

-- https://github.com/mjg59/python-broadlink/blob/master/protocol.md#checksum
local function add_checksum(packet)
    local checksum = get_checksum(packet)
    log.debug('add_checksum() checksum='..checksum)

    local packet_with_checksum =
        packet:sub(1,32) ..
        string.pack('<H', checksum) ..
        packet:sub(35)

    return packet_with_checksum
end

-- AES encrypt a packet payload
--  @param  payload string - data to encrypt
--  @param  encryption_key lockbox.util.Array - AES encryption key
--  @return string - the encrypted data
-- https://github.com/mjg59/python-broadlink/blob/3c183eaaef6cbaf9c1154b232116bc130cd2113f/protocol.md#command-packet-format
-- https://github.com/mjg59/python-broadlink/blob/3c183eaaef6cbaf9c1154b232116bc130cd2113f/broadlink/device.py#L163
local function encrypt_payload(payload, encryption_key)
    local aescipher=CBCMode.Cipher()
        .setKey(encryption_key)
        .setBlockCipher(AES128Cipher)
        .setPadding(ZeroPadding)
        .init()
        .update(Stream.fromArray(Array.fromHex(config.encrypt_INIT_VECT)))

    return Array.toString(
        aescipher
            .update(Stream.fromArray(Array.fromString(payload)))
            .finish()
            .asBytes()
    )
end

-- AES decrypt a packet payload
--  @param  payload string - data to encrypt
--  @param  encryption_key lockbox.util.Array - AES encryption key
--  @return string - the encrypted data
-- https://github.com/mjg59/python-broadlink/blob/3c183eaaef6cbaf9c1154b232116bc130cd2113f/protocol.md#command-packet-format
-- https://github.com/mjg59/python-broadlink/blob/3c183eaaef6cbaf9c1154b232116bc130cd2113f/broadlink/device.py#L163
local function decrypt_payload(payload, encryption_key)
    local aesdecipher=CBCMode.Decipher()
        .setKey(encryption_key)
        .setBlockCipher(AES128Cipher)
        .setPadding(ZeroPadding)
        .init()
        .update(Stream.fromArray(Array.fromHex(config.encrypt_INIT_VECT)))

    return Array.toString(
        aesdecipher
            .update(Stream.fromArray(Array.fromString(payload)))
            .finish()
            .asBytes()
    )
end

-----------------------------------------------------------
-- discovery via multicast
-- see: https://github.com/mjg59/python-broadlink/blob/master/protocol.md#network-discovery

-- broadcast a Broadlink udp multicast discovery packet
-- @return string - response payload
-- @return string - remote ip
function broadlink.broadcast_discovery()
    log.debug('broadlink.broadcast_discovery() entered')
    -- construct discovery packet
    local now = os.date('*t')
    local discover_packet = string.pack(
        '<xxxxxxxxxxxx HBBBBBB xxxx xxxxxx xx xxxxxx B xxxxxxxxx',
        now['year'], now['sec'], now['min'], now['hour'], now['wday'], now['day'], now['month'],
        0x06
    )
    discover_packet = add_checksum(discover_packet)
    log.debug('discover_packet: ' .. printhex(discover_packet))

    -- udp broadcast discovery packet
    local udp = socket.udp()
    udp:setsockname('*', 0)
    udp:setoption('broadcast', true)
    udp:settimeout(config.DISCOVER_TIMEOUT_SEC)
    log.info('Sending UDP broadcast to discover devices on network')
    udp:sendto(discover_packet, DISCOVER_ADDRESS, DISCOVER_PORT)

    local res, remote_ip = udp:receivefrom()
    udp:close()

    if res ~= nil then
        log.info('remote_ip: '..remote_ip..' response: ' .. printhex(res))
        return res, remote_ip
    end
    log.debug('broadlink.broadcast_discovery() exiting')
    return nil
end

-- parse a response to a multicast discovery packet
-- @return int - device_type
-- @return string - device_macaddr
function broadlink.parse_discovery_resp(resp)
    local device_type = string.unpack('<I2', resp, 0x35)
    local device_macaddr = ('%2x:%2x:%2x:%2x:%2x:%2x'):format(
        resp:byte(0x40),
        resp:byte(0x3f),
        resp:byte(0x3e),
        resp:byte(0x3d),
        resp:byte(0x3c),
        resp:byte(0x3b)
    )
    return device_type, device_macaddr
end


-----------------------------------------------------------
-- direct (non-multicast) commands


-- send a broadlink packet
-- @param packet_type int
-- @param payload string - payload bytes
-- @param st_device object - the SmartThings device
-- @param encryption_key lockbox.util.Array - optional AES encryption key. If nil, st_device's property 'broadlink_encryption_key' is used
-- @returns string - response bytes
local function send_packet(packet_type, payload, st_device, encryption_key)
    log.info('entered send_packet() packet_type='..string.format('0x%02x',packet_type)..' payload len='..#payload..'bytes encryption_key=')
    packet_counter = ((packet_counter + 1) | 0x8000) & 0xFFFF

    -- translate macaddr from colon-separated hex string to 6 bytes of binary
    local device_macaddr = ''
    for mac_field in string.gmatch(st_device.device_network_id, "([^:]+)") do
        device_macaddr = string.pack('B', tonumber(mac_field, 16)) .. device_macaddr
    end

    log.info('send_packet() device_network_id='..st_device.device_network_id)
    log.info('send_packet() device_macaddr='..printhex(device_macaddr))

    local broadlink_device_id = st_device:get_field('broadlink_device_id') or 0 -- zero before auth
    log.info('send_packet() broadlink_device_id='..broadlink_device_id)


    -- packet = bytearray(0x38)
    -- packet[0x00:0x08] = bytes.fromhex("5aa5aa55 5aa5aa55")
    -- packet[0x24:0x26] = self.devtype.to_bytes(2, "little")
    -- packet[0x26:0x28] = packet_type.to_bytes(2, "little")
    -- packet[0x28:0x2A] = self.count.to_bytes(2, "little")
    -- packet[0x2A:0x30] = self.mac[::-1]
    -- packet[0x30:0x34] = self.id.to_bytes(4, "little")

    local unencrypted_payload_checksum = get_checksum(payload)

    local packet = string.pack(
        '>I4I4 <xxxxxxxxxxxxxxxxxxxxxxxx xx xx I2 I2 I2 c6 I4 I2 xx',
        0x5aa5aa55, 0x5aa5aa55,
        st_device:get_field("broadlink_device_type"),
        packet_type,
        packet_counter,
        device_macaddr,
        broadlink_device_id,
        unencrypted_payload_checksum
    )

    -- pad payload to 16byte boundary
    local pad_len = (16 - #payload) % 16
    log.debug("send_packet() payload pad_len="..pad_len)
    payload = payload .. string.rep("\0", pad_len)
    log.debug("send_packet() padded plaintext payload="..printhex(payload))

    if encryption_key == nil then
        encryption_key = st_device:get_field('broadlink_encryption_key')
    end
    log.debug("send_packet() encryption_key="..Array.toHex(encryption_key))
    local encrypted_payload = encrypt_payload(payload, encryption_key)
    log.debug("send_packet() encrypted payload="..printhex(encrypted_payload))

    -- p_checksum = sum(payload, 0xBEAF) & 0xFFFF
    -- packet[0x34:0x36] = p_checksum.to_bytes(2, "little")

    -- padding = (16 - len(payload)) % 16
    -- payload = self.encrypt(payload + bytes(padding))
    -- packet.extend(payload)

    -- checksum = sum(packet, 0xBEAF) & 0xFFFF
    -- packet[0x20:0x22] = checksum.to_bytes(2, "little")

    packet = packet .. encrypted_payload
    local packet_checksum = string.pack('<I2', get_checksum(packet))
    log.debug("send_packet() final packet (no checksum)="..printhex(packet))
    packet = packet:sub(1, 0x20) .. packet_checksum .. packet:sub(0x23)
    log.debug("send_packet() final packet (with checksum)="..printhex(packet))

    -- send packet via UDP
    log.info('sending packet via UDP to '..st_device:get_field("ip"))
    local udp = socket.udp()
    udp:setsockname('*', 0)
    udp:settimeout(config.COMMAND_TIMEOUT_SEC)
    udp:sendto(packet, st_device:get_field("ip"), COMMAND_PORT)

    local resp = udp:receive()
    log.debug("send_packet() response="..printhex(resp))

    -- TODO: response data validation (length, checksum)

    return resp
end

-- Check for error code in a response. Raises error() if present
-- @param error_field string - bytes from response
-- @returns string -- error code bytes, or ""
local function check_error(error_field)
    log.debug('check_error(): error_field='..printhex(error_field))
    local error_code = string.unpack('<I2', error_field)
    if error_code ~= 0 then
        log.error('check_error(): error code='..error_code)
        return error_code
    end
    return ""
end

-- Send a command+data to the device
-- @returns string, string - response data, error code
local function _send(command, data, st_device)
    log.info('_send(): command='..string.format('0x%02x', command)..' data='..printhex(data))
    -- packet = struct.pack("<HI", len(data) + 4, command) + data
    local packet = string.pack('<I2 I4', string.len(data) + 4, command)..data
    local resp = send_packet(0x6A, packet, st_device)

    log.debug('_send(): response='..printhex(resp))
    local error_code = check_error(resp:sub(0x23, 0x24))
    if error_code ~= "" then
        return "", error_code
    end

    local payload = decrypt_payload(resp:sub(0x39), st_device:get_field("broadlink_encryption_key"))
    local p_len = string.unpack('<I2', payload)
    log.debug('_send(): response payload (decrypted)='..printhex(payload))
    log.debug('_send(): p_len='..p_len)

    local resp_data = payload:sub(0x07, p_len + 2)
    log.debug('_send(): resp_data='..printhex(resp_data))
    return resp_data, error_code
end

-- Send a remote code
-- @param remote_code string - remote code data. Either "base64:<b64 chars>" or "<hex chars>"
function broadlink.send_data(remote_code, st_device)
    log.debug('entered send_data(): remote_code='..remote_code)
    local data_bytes
    if remote_code:find("^base64:") then
        data_bytes = st_base64.decode(remote_code:sub(8))
    else
        data_bytes = Array.toString(Array.fromHex(remote_code))
    end
    _send(0x2, data_bytes, st_device)
end

-- Enter learning mode
function broadlink.enter_learning(st_device)
    log.debug('entered enter_learning()')
    _send(0x3, '', st_device)
end

-- Attempt to fetch learned code.
-- Learning should have been started before calling this function. It polls for a code
-- @param st_device table - smartthings device object
-- @param attempt number - attempt number
function broadlink.fetch_learned(st_device, attempt)
    log.debug('entered fetch_learned() attempt='..attempt)
    local data, error_code = _send(0x4, '', st_device)
    if error_code == ""  and  data ~= "" then
        -- remote code data fetched sucessfully 
        local data_b64 = st_base64.encode(data)
        st_device:emit_component_event(st_device.profile.components.learn, capability_learnCode.code("base64:"..data_b64))
    else
        -- no data yet
        if attempt < config.MAX_FETCH_LEARNED_ATTEMPTS then
            -- try again
            st_device.thread:call_with_delay(
                1,
                function()
                    broadlink.fetch_learned(st_device, attempt + 1)
                end
            )
        else
            -- give up
            st_device:emit_component_event(st_device.profile.components.learn, capability_learnCode.code("--no code received--"))
        end
    end

end

-- Send Broadlink protocol "authenticate"
function broadlink.auth(st_device)
    log.info('auth() entered')

    local auth_payload = string.pack(
        '<xxxx c16 xxxxxxxxxx B xxxxxxxxxxxxxx Bxx c32',
        "1111111111111111",
        1,
        1,
        "Test 1"
    )
    log.debug('auth(): packet='..printhex(auth_payload))

    local response = send_packet(0x65, auth_payload, st_device, Array.fromHex(config.encrypt_INIT_KEY))
    local payload_enc = response:sub(0x39)
    log.debug('auth(): response payload encrypted='..printhex(payload_enc))
    local payload_plaintext = decrypt_payload(payload_enc, Array.fromHex(config.encrypt_INIT_KEY))
    log.debug('auth(): response payload decrypted='..printhex(payload_plaintext))
    local broadlink_device_id = string.unpack('<I4', payload_plaintext)
    st_device:set_field("broadlink_device_id", broadlink_device_id)
    log.debug('auth(): response broadlink_device_id='..broadlink_device_id)
    local broadlink_encryption_key = payload_plaintext:sub(0x05, 0x14)
    st_device:set_field("broadlink_encryption_key", Array.fromString(broadlink_encryption_key))
    log.debug('auth(): response broadlink_encryption_key='..printhex(broadlink_encryption_key))
end

return broadlink