local inHandler = false
local contHashes = {
  `prop_container_old1`,
  `prop_container_03_ld`,
  `prop_container_03a`,
  `prop_container_03b`,
  `prop_container_03mb`,
  `prop_contr_03b_ld`,
  `prop_container_04a`,
  `prop_container_04mb`
}

---@param model number|string
local function loadModel(model)
  if type(model) == 'string' then model = joaat(model) end
  if HasModelLoaded(model) then return end
  RequestModel(model)
  repeat Wait(0) until HasModelLoaded(model)

end

local function createContainers()
  local hash = `prop_contr_03b_ld`
  local containers = { vector4(-40.8, -2418.85, 6.0, 85.54) }
  for i = 1, #containers do
    local container = containers[i]
    loadModel(hash)
    local obj = CreateObject(hash, container.x, container.y, container.z, true, true, false)
    SetEntityHeading(obj, container.w)
    SetEntityDynamic(obj, false)
    SetActivateObjectPhysicsAsSoonAsItIsUnfrozen(obj, true)
    FreezeEntityPosition(obj, false)
  end
  SetModelAsNoLongerNeeded(hash)
end

local function initContainers()
  local containers = GetGamePool('CObject')
  for i = 1, #containers do
    local container = containers[i]
    for j = 1, #contHashes do
      if GetEntityModel(container) == contHashes[j] then
        SetEntityAsMissionEntity(container, true, true)
      end
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
  if not IsPedInAnyVehicle(PlayerPedId(), false) then return false end
  if vehicle == 0 or not DoesEntityExist(vehicle) or not IsVehicleDriveable(vehicle, false) then return false end
  if not IsVehicleModel(vehicle, `handler`) then return false end
  return true
end

---@param vehicle number
---@return number
local function getClosestContainer(vehicle)
  local coords = GetEntityCoords(vehicle, true)
  for i = 1, #contHashes do
    local container = GetClosestObjectOfType(coords.x, coords.y, coords.z, 15.0, contHashes[i], false, false, false)
    if container ~= 0 and DoesEntityExist(container) then return container end
  end
  return 0
end

---@param vehicle number
---@param container number
---@return boolean isValid
local function isContainerValid(vehicle, container)
  if container == 0 or not DoesEntityExist(container) then return false end
  if getClosestContainer(vehicle) ~= container then return false end
  return true
end

---@param vehicle number
---@param container number
---@return boolean
local function IsAnyEntityAttachedToHandlerFrame2(vehicle, container)
  if not container then return false end
  if not IsEntityAttachedToEntity(container, vehicle) then return false end
  return true
end

---@param vehicle number
---@param container number
---@return boolean
local function IsHandlerFrameAboveContainer2(vehicle, container)
  local bone = GetEntityBoneIndexByName(vehicle, 'frame_2')
  local pos = GetWorldPositionOfEntityBone(vehicle, bone)
  local coords = GetEntityCoords(container, true)
  if not IsEntityUpsidedown(container) and pos.z > coords.z or pos.z < coords.z and #(pos - coords) < 3.75 then return true end
  return false
end

---@param vehicle number
---@param container number
local function AttachContainerToHandlerFrame2(vehicle, container)
  local ped = PlayerPedId()
  vehicle = vehicle ~= 0 and vehicle or GetVehiclePedIsIn(ped, false)
  container = container ~= 0 and container or getClosestContainer(vehicle)
  local bone = GetEntityBoneIndexByName(vehicle, 'frame_2')
  SetEntityAsMissionEntity(container, true, true)
  PlaySoundFromEntity(-1, 'Attach_Container', vehicle, 'CRANE_SOUNDS', true, 0)
  AttachEntityToEntity(container, vehicle, bone, 0.0, 1.78, -2.82, 0.0, 0.0, 90.0, false, false, true, false, 1, true)
  SetObjectPhysicsParams(container, 1000.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1, -1)
  SetActivateObjectPhysicsAsSoonAsItIsUnfrozen(container, true)
  FreezeEntityPosition(container, false)
end

---@param vehicle number
---@param container number
local function DetachContainerFromHandlerFrame2(vehicle, container)
  local ped = PlayerPedId()
  vehicle = vehicle ~= 0 and vehicle or GetVehiclePedIsIn(ped, false)
  container = container ~= 0 and container or getClosestContainer(vehicle)
  PlaySoundFromEntity(-1, 'Detach_Container', vehicle, 'CRANE_SOUNDS', true, 0)
  DetachEntity(container, true, false)
  SetEntityDynamic(container, true)
  FreezeEntityPosition(container, false)
  ApplyForceToEntity(container, 3, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0, true, false, true, false, true)
  SetEntityAsNoLongerNeeded(container)
end

local listening = false
---@param key number
---@return boolean|promise 
local function listen4Key(key)
  if listening then return false end
  listening = true
  local time = GetGameTimer()
  while listening do
    Wait(0)
    if not inHandler or not listening then break end
    if IsControlJustPressed(0, key) then
      listening = false
      return true
    end
    if timer(time, 5000) then
      listening = false
      return false
    end
  end
  return false
end

local Await = Citizen.Await
---@param vehicle number
local function handlerThread(vehicle)
  local ped = PlayerPedId()
  local container, model
  local justAttached = false
  local time, sleep = GetGameTimer(), 0
  vehicle = vehicle ~= 0 and vehicle or GetVehiclePedIsIn(ped, false)
  inHandler = true
  CreateThread(function()
    while inHandler do
      Wait(sleep)
      SetInputExclusive(0, Config.Key)
      if not inHandler then
        listening = false
        return
      end
      if not isVehicleAHandler(vehicle) then
        inHandler = false
        return
      end
      if not IsAnyEntityAttachedToHandlerFrame(vehicle) and not IsAnyEntityAttachedToHandlerFrame2(vehicle, container) then
        if not isContainerValid(vehicle, container) then
          container = getClosestContainer(vehicle)
          model = container ~= 0 and GetEntityModel(container) or 0
        end
        if container ~= 0 then
          sleep = 500
          if timer(time, 1000) then
            sleep = 250
            if IsHandlerFrameAboveContainer(vehicle, container) or IsHandlerFrameAboveContainer2(vehicle, container) then
              if listen4Key(Config.Key) then
                if not IsHandlerFrameAboveContainer(vehicle, container) and not IsHandlerFrameAboveContainer2(vehicle, container) then break end
                if model ~= `prop_contr_03b_ld` then
                  AttachContainerToHandlerFrame2(vehicle, container)
                else
                  AttachContainerToHandlerFrame(vehicle, container)
                end
                justAttached = true
              end
            end
          end
        else
          sleep = 1000
        end
      else
        if model ~= `prop_contr_03b_ld` then
          sleep = 500
          if timer(time, 1000) then
            if listen4Key(Config.Key) then
              DetachContainerFromHandlerFrame2(vehicle, container)
              sleep = 1000
              if justAttached then
                time = GetGameTimer()
                justAttached = false
              end
            end
          end
        else
          sleep = 1000
          if justAttached then
            time = GetGameTimer()
            justAttached = false
          end
        end
      end
    end
  end)
end

AddEventHandler('gameEventTriggered', function(name, args)
  if name ~= 'CEventNetworkPlayerEnteredVehicle' then return end
  local netId = args[1]  -- Network ID of the client? always returns 128 on a locally hosted server
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
  inHandler, listening = false, false
end)

RegisterCommand('containers', function()
  createContainers()
end, false)
