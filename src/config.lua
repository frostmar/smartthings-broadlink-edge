local config = {}
-- device info
-- NOTE: In the future this information may be submitted through
--       the Developer Workspace to avoid hardcoded values.
config.DEVICE_PROFILE='BroadlinkRM.v1' -- matches profiles/BroadlinkRM.yaml field 'name'
config.DEVICE_TYPE='LAN'

config.DISCOVER_TIMEOUT_SEC=10
config.COMMAND_TIMEOUT_SEC=10

config.MAX_FETCH_LEARNED_ATTEMPTS=20

config.encrypt_INIT_KEY  = "097628343fe99e23765c1513accf8b02"
config.encrypt_INIT_VECT = "562e17996d093d28ddb3ba695a2e6f58"

return config