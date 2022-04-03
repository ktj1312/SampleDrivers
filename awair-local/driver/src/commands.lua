local caps = require('st.capabilities')
local utils = require('st.utils')
local neturl = require('net.url')
local log = require('log')
local json = require('dkjson')
local http = require('socket.http')
local ltn12 = require('ltn12')

local command_handler = {}

------------------
-- Refresh command
function command_handler.refresh(_, device)
  -- Define online status
  device:online()

  local isSuccess = true

  isSuccess = command_handler.update_airdata(device)
  isSuccess = command_handler.update_device_status(device)
  
  if isSuccess ~= true then
    -- Set device as offline
    device:offline()
  end
  
end

------------------------
-- Update Airdata Values
function command_handler.update_airdata(device)
  -- Refresh Airdata
  log.trace('Refreshing Airdata')
    
  local success, data = command_handler.send_lan_command(
    device.device_network_id,
    'GET',
    'air-data/latest')

    log.trace(data)

  -- Check success
  if success then
    log.trace(data)
    local resp = json.decode(table.concat(data)..'}')

    device:emit_event(caps.airQualitySensor.airQuality(resp.score))
    device:emit_event(caps.carbonDioxideMeasurement.carbonDioxide(resp.co2))
    return true
  else
    log.error('failed to poll air data')
    return false
  end
end

------------------------
-- Update Device Status
function command_handler.update_device_status(device)
  -- Refresh Device Status
  log.trace('Refreshing Device Status')

  local success, data = command_handler.send_lan_command(
    device.device_network_id,
    'GET',
    'settings/config/data')

    log.trace(data)

  -- Check success
  if success then
    log.trace(data)
    local resp = json.decode(table.concat(data)..'}')
    
    device:emit_event(caps.battery.battery(resp.score))
    device:emit_event(caps.carbonDioxideMeasurement.carbonDioxide(resp.co2))
    return true
  else
    log.error('failed to poll device state')
    return false
  end
end

------------------------
-- Send LAN HTTP Request
function command_handler.send_lan_command(url, method, path)
  local dest_url = url..'/'..path
  local res_body = {}

  log.trace('request to ' ..dest_url..' method ' ..method)

  -- HTTP Request
  local _, code = http.request({
    method=method,
    url=dest_url,
    sink=ltn12.sink.table(res_body),
    headers={
      ['Accept'] = 'application/json'
      -- ,
      -- ['connection'] = '',
      -- ['te'] = ''
    }})

  log.trace('response code ' ..code)

  -- Handle response
  if code == 200 then
    return true, res_body
  end
  return false, nil
end

return command_handler
