local inHandler = false
local containerHash = `prop_contr_03b_ld`

---@param model number
local function loadModel(model)
  if HasModelLoaded(model) then return end
  RequestModel(model)
  repeat Wait(0) until HasModelLoaded(model)
end

local function createContainers()
  local containers = {vector4(-40.8, -2418.85, 6.0, 85.54)}
  for i = 1, #containers do
    local container = containers[i]
    loadModel(containerHash)
    local obj = CreateObject(containerHash, container.x, container.y, container.z, true, true, false)
    SetEntityHeading(obj, container.w)
    SetModelAsNoLongerNeeded(containerHash)
  end
end

local function initContainers()
  local containers = GetGamePool('CObject')
  for i = 1, #containers do
    local container = containers[i]
    if GetEntityModel(container) == containerHash then
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

---@param vehicle number
---@return boolean
local function isVehicleAHandler(vehicle)
  if vehicle == 0 or not DoesEntityExist(vehicle) or not IsVehicleDriveable(vehicle, false) then return false end
  if not IsPedInAnyVehicle(PlayerPedId(), false) then return false end
  if not IsVehicleModel(vehicle, `handler`) then return false end
  return true
end

---@param vehicle number
---@param container number
---@return boolean isValid
local function isContainerValid(vehicle, container)
  if container == 0 or not DoesEntityExist(container) then return false end
  if GetClosestObjectOfType(GetEntityCoords(vehicle, true), 15.0, containerHash, false, false, false) ~= container then return false end
  return true
end

local listening = false
---@param key number
---@return boolean
local function listen4Key(key)
  if listening then return false end
  listening = true
  while listening do
    Wait(0)
    if IsControlJustPressed(0, key) then
      listening = false
      return true
    end
  end
end

local Await = Citizen.Await
---@param vehicle number
local function handlerThread(vehicle)
  local ped = PlayerPedId()
  local container = nil 
  local justAttached = false
  local time, sleep = GetGameTimer(), 0
  vehicle = vehicle ~= 0 and vehicle or GetVehiclePedIsIn(ped, false)
  inHandler = true
  CreateThread(function()
    while inHandler do
      Wait(sleep)
      SetInputExclusive(0, Config.Key)
      if not isVehicleAHandler(vehicle) then
        inHandler = false
        return
      end
      if not IsAnyEntityAttachedToHandlerFrame(vehicle) then
        if not isContainerValid(container) then
          container = GetClosestObjectOfType(GetEntityCoords(vehicle, true), 15.0, containerHash, false, false, false)
        end
        if container ~= 0 then
          sleep = 250
          if timer(time, 1000) and IsHandlerFrameAboveContainer(vehicle, container) then
            local p = promise.new()
            if listen4Key(Config.Key) then
              AttachContainerToHandlerFrame(vehicle, container)
              justAttached = true
              p:resolve()
            else
              p:reject()
            end
            Await(p)
          end
        else 
          sleep = 1000
        end
      else
        sleep = 1000
        if justAttached then
          time = GetGameTimer()
          justAttached = false
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
  if not isVehicleAHandler(veh) then return end
  handlerThread(veh)
end)

AddEventHandler('onResourceStart', function(name)
  if name ~= GetCurrentResourceName() then return end
  initContainers()
  if not IsPlayerPlaying(PlayerId()) then return end
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if not isVehicleAHandler(veh) then return end
  handlerThread(veh)
end)

AddEventHandler('onResourceStop', function(name)
  if name ~= GetCurrentResourceName() then return end
  inHandler = false
end)

RegisterCommand('containers', function()
  createContainers()
end, false)
