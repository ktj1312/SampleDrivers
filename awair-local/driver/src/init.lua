local Driver = require('st.driver')
local caps = require('st.capabilities')

-- local imports
local discovery = require('discovery')
local lifecycles = require('lifecycles')
local commands = require('commands')

--------------------
-- Driver definition
local driver =
  Driver(
    'LAN-Awair',
    {
      discovery = discovery.start,
      lifecycle_handlers = lifecycles,
      supported_capabilities = {
        caps.refresh
      },
      capability_handlers = {
        -- Refresh command handler
        [caps.refresh.ID] = {
          [caps.refresh.commands.refresh.NAME] = commands.refresh
        }
      }
    }
  )

--------------------
-- Initialize Driver
driver:run()
