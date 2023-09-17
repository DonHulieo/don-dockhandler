
---@param model number
local function reqMod(model)
  if HasModelLoaded(model) then return end
  RequestModel(model)
  repeat Wait(0) until HasModelLoaded(model)
end

local function createContainers()
  local containers = {vector4(-40.8, -2418.85, 6.0, 85.54)}
  for i = 1, #containers do
    local container = containers[i]
    local model = `prop_contr_03b_ld`
    reqMod(model)
    local obj = CreateObject(model, container.x, container.y, container.z, true, true, false)
    SetEntityHeading(obj, container.w)
    SetModelAsNoLongerNeeded(hash)
  end
end

local function initContainers()
  local hash = `prop_contr_03b_ld`
  local containers = GetGamePool('CObject')
  for i = 1, #containers do
    local container = containers[i]
    if GetEntityModel(container) == hash then
      SetEntityAsMissionEntity(container, true, true)
    end
  end
end

---@param time number
---@param limit number
---@return boolean
local function timer(time, limit)
  local current = GetGameTimer()
  if current - time > limit then
    return true
  end
  return false
end

local inHandler = false
---@param veh number
local function handlerThread(veh)
  local ped = PlayerPedId()
  local veh = veh ~= 0 and veh or GetVehiclePedIsIn(ped, false)
  local container, hash = nil, `prop_contr_03b_ld`
  local attached = false
  local time, sleep = GetGameTimer(), 0
  inHandler = true
  CreateThread(function()
    while inHandler do
      Wait(sleep)
      SetInputExclusive(0, Config.Key)
      if veh == 0 or not DoesEntityExist(veh) or not IsVehicleDriveable(veh, false) or not IsVehicleModel(veh, `handler`) or not IsPedInAnyVehicle(ped, false) then
        inHandler = false
        return
      end
      if not IsAnyEntityAttachedToHandlerFrame(veh) then
        if container == 0 or not DoesEntityExist(container) or DoesEntityExist(container) and GetClosestObjectOfType(GetEntityCoords(veh, true), 15.0, hash, true, false, true) ~= container then
          container = GetClosestObjectOfType(GetEntityCoords(veh, true), 15.0, hash, true, false, true)
        end
        if container ~= 0 and DoesEntityExist(container) then
          sleep = 100
          if timer(time, 1000) and IsHandlerFrameAboveContainer(veh, container) then
            sleep = 0
            if IsControlJustPressed(0, Config.Key) then
              AttachContainerToHandlerFrame(veh, container)
              attached = true
            end
          end
        else 
          sleep = 1000
        end
      else
        sleep = 1000
        if attached then
          time = GetGameTimer()
          attached = false
        end
      end
    end
  end)
end

AddEventHandler('gameEventTriggered', function(name, args)
  if name ~= 'CEventNetworkPlayerEnteredVehicle' then return end
  local netId = args[1] -- Network ID of the client? always returns 128 on a locally hosted server
  local vehNet = args[2] -- Vehicle handle
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 or not DoesEntityExist(veh) or not IsVehicleDriveable(veh, false) then return end
  if not IsVehicleModel(veh, `handler`) then return end
  handlerThread(veh)
end)

AddEventHandler('onResourceStart', function(name)
  if name ~= GetCurrentResourceName() then return end
  initContainers()
  if not IsPlayerPlaying(PlayerId()) then return end
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh == 0 or not DoesEntityExist(veh) or not IsVehicleDriveable(veh, false) then return end
  if not IsVehicleModel(veh, `handler`) then return end
  handlerThread(veh)
end)

AddEventHandler('onResourceStop', function(name)
  if name ~= GetCurrentResourceName() then return end
  inHandler = false
end)

RegisterCommand('containers', function()
  createContainers()
end, false)
