local socket = require('socket')
local http = require('socket.http')
local ltn12 = require('ltn12')
local log = require('log')
local config = require('config')
local json = require('dkjson')

-----------------------
-- SSDP Response parser
local function parse_ssdp(data)
  local res = {}
  res.status = data:sub(0, data:find('\r\n'))
  for k, v in data:gmatch('([%w-]+): ([%a+-: /=]+)') do
    res[k:lower()] = v
  end
  return res
end

-- Fetching awair device metadata
-- from SSDP Response Location header
local function fetch_device_info(url)
  local awair_info_url = url .. '/settings/config/data'
  
  log.trace('fetch_device_info request to url : ' .. awair_info_url)
  
  local res = {}
  local _, code = http.request({
    method='GET',
    url=awair_info_url,
    sink=ltn12.sink.table(res)
  })

  if code == 200 then
    res = json.decode(table.concat(res)..'}')
  
    local modelName
    if string.find(res.device_uuid, "awair-omni") then
      modelName = 'AwairOmni'
    else
      modelName = 'AwairR2'
    end
  
    return {
      name=modelName,
      vendor='Awair Smart Air Management',
      mn='Awair Co.',
      model=modelName,
      location=res.ip
    }
  else
    log.error('failed to retrive info status ' .. code)
    return nil
  end
end

-- This function enables a UDP
-- Socket and broadcast a single
-- M-SEARCH request, i.e., it
-- must be looped appart.
local function find_device()
  -- UDP socket initialization
  local upnp = socket.udp()
  upnp:setsockname('*', 0)
  upnp:setoption('broadcast', true)
  upnp:settimeout(config.MC_TIMEOUT)

  -- broadcasting request
  log.info('===== SCANNING NETWORK...')
  upnp:sendto(config.MSEARCH, config.MC_ADDRESS, config.MC_PORT)

  -- Socket will wait n seconds
  -- based on the s:setoption(n)
  -- to receive a response back.
  local res = upnp:receivefrom()

  -- close udp socket
  upnp:close()

  if res ~= nil then
    return res
  end
  return nil
end

local function create_device(driver, device)
  log.info('===== CREATING DEVICE...')
  log.info('===== DEVICE DESTINATION ADDRESS: '..device.location)
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = device.location,
    label = device.name,
    profile = config.DEVICE_PROFILE,
    manufacturer = device.mn,
    model = device.model,
    vendor_provided_label = device.UDN
  }
  return driver:try_create_device(metadata)
end

-- Discovery service which will
-- invoke the above private functions.
--    - find_device
--    - parse_ssdp
--    - fetch_device_info
--    - create_device
--
-- This resource is linked to
-- driver.discovery and it is
-- automatically called when
-- user scan devices from the
-- SmartThings App.
local disco = {}
function disco.start(driver, opts, cons)
  while true do
    local device_res = find_device()

    log.trace(device_res)

    if device_res ~= nil then
      device_res = parse_ssdp(device_res)
      log.info('===== DEVICE FOUND IN NETWORK...')
      log.info('===== DEVICE LOCATED IP : '..device_res.location)

      local device = fetch_device_info(device_res.location)
      if device ~= nil then
        return create_device(driver, device)
      else
        log.error('===== DEVICE INFO RETRIVE FAIL =====')
      end
    end
    log.error('===== DEVICE NOT FOUND IN NETWORK')
  end
end

return disco
