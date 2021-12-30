local caps = require('st.capabilities')
local utils = require('st.utils')
local neturl = require('net.url')
local log = require('log')
local json = require('dkjson')
local http = require('socket.http')
local ltn12 = require('ltn12')

local command_handler = {}

---------------
-- Ping command
function command_handler.ping(address, port, device)
  local ping_data = {ip=address, port=port, ext_uuid=device.id}
  return command_handler.send_lan_command(
    device.device_network_id, 'POST', 'ping', ping_data)
end
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

  local resp = json.decode(table.concat(data)..'}')

  -- Check success
  if success then
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

  local resp = json.decode(table.concat(data)..'}')

  -- Check success
  if success then
    log.trace(resp)
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
function command_handler.send_lan_command(url, method, path, body)
  local dest_url = url..'/'..path
  local query = neturl.buildQuery(body or {})
  local res_body = {}

  -- HTTP Request
  local _, code = http.request({
    method=method,
    url=dest_url..'?'..query,
    sink=ltn12.sink.table(res_body),
    headers={
      ['Content-Type'] = 'application/x-www-urlencoded'
    }})

  -- Handle response
  if code == 200 then
    return true, res_body
  end
  return false, nil
end

return command_handler
