--- This module contains the STATEMACHINE class.
-- This development is based on a state machine implementation made by Conroy Kyle.
-- The state machine can be found here: https://github.com/kyleconroy/lua-state-machine
--
-- I've taken the development and enhanced it to make the state machine hierarchical...
-- It is a fantastic development, this module.
--
-- ===
--
-- 1) @{Workflow#STATEMACHINE} class, extends @{Base#BASE}
-- ==============================================
--
-- 1.1) Add or remove objects from the STATEMACHINE
-- --------------------------------------------
-- @module StateMachine
-- @author FlightControl


--- STATEMACHINE class
-- @type STATEMACHINE
-- @extends Core.Base#BASE
STATEMACHINE = {
  ClassName = "STATEMACHINE",
}

--- Creates a new STATEMACHINE object.
-- @param #STATEMACHINE self
-- @return #STATEMACHINE
function STATEMACHINE:New( options )

  -- Inherits from BASE
  local self = BASE:Inherit( self, BASE:New() )


  --local self = routines.utils.deepCopy( self ) -- Create a new self instance

  --assert(options.events)

  --local MT = {}
  --setmetatable( self, MT )
  --self.__index = self

  self.options = options
  self.current = options.initial or 'none'
  self.events = {}
  self.subs = {}
  self.endstates = {}

  for _, event in pairs(options.events or {}) do
    self:E({ "events", event })
    self:_eventmap( self.events, event )
  end

  for name, callback in pairs(options.callbacks or {}) do
    self:E("callbacks")
    self[name] = callback
  end

  for name, sub in pairs( options.subs or {} ) do
    self:E("sub")
    self:_submap( self.subs, sub, name )
  end

  for name, endstate in pairs( options.endstates or {} ) do
    self:E("endstate")
    self.endstates[endstate] = endstate
  end

  return self
end

function STATEMACHINE:SetInitialState( State )
  self.current = State
end

function STATEMACHINE:AddAction( From, Event, To )

  local event = {}
  event.from = From
  event.name = Event
  event.to = To

  self:E( event )

  self:_eventmap( self.events, event )
end


--- Set the default @{Process} template with key ProcessName providing the ProcessClass and the process object when it is assigned to a @{Controllable} by the task.
-- @return Process#PROCESS
function STATEMACHINE:AddProcess( From, Event, Process, ReturnEvents )

  local sub = {}
  sub.FromParent = From
  sub.EventParent = Event
  sub.fsm = Process
  sub.event = "Start"
  sub.ReturnEvents = ReturnEvents

  self:_submap( self.subs, sub, nil )
  
  self:AddAction( From, Event, "*" )

  return Process
end

function STATEMACHINE:GetSubs()

  return self.options.subs
end


function STATEMACHINE:LoadCallBacks( CallBackTable )

  for name, callback in pairs( CallBackTable or {} ) do
    self[name] = callback
  end

end

function STATEMACHINE:_eventmap( events, event )

    local name = event.name
    local __name = "__" .. event.name
    self[name] = self[name] or self:_create_transition(name)
    self[__name] = self[__name] or self:_delayed_transition(name)
    self:T( "Added methods: " .. name .. ", " .. __name )
    events[name] = self.events[name] or { map = {} }
    self:_add_to_map( events[name].map, event )

end

function STATEMACHINE:_submap( subs, sub, name )
  self:E( { sub = sub, name = name } )
  subs[sub.FromParent] = subs[sub.FromParent] or {}
  subs[sub.FromParent][sub.EventParent] = subs[sub.FromParent][sub.EventParent] or {}
  local Index = #subs[sub.FromParent][sub.EventParent] + 1
  subs[sub.FromParent][sub.EventParent][Index] = {}
  subs[sub.FromParent][sub.EventParent][Index].fsm = sub.fsm
  subs[sub.FromParent][sub.EventParent][Index].event = sub.event
  subs[sub.FromParent][sub.EventParent][Index].ReturnEvents = sub.ReturnEvents or {} -- these events need to be given to find the correct continue event ... if none given, the processing will stop.
  subs[sub.FromParent][sub.EventParent][Index].name = name
  subs[sub.FromParent][sub.EventParent][Index].fsmparent = self
end


function STATEMACHINE:_call_handler(handler, params)
  if handler then
    return handler( self, unpack(params) )
  end
end

function STATEMACHINE._handler( self, EventName, ... )

  self:F( { EventName, ... } )

  local can, to = self:can(EventName)
  self:T( { EventName, can, to } )

  local ReturnValues = nil

  if can then
    local from = self.current
    local params = { ..., EventName, from, to  }

    if self:_call_handler(self["onbefore" .. EventName], params) == false
      or self:_call_handler(self["onleave" .. from], params) == false then
      return false
    end

    self.current = to

    local execute = true

    local subtable = self:_gosub( from, EventName )
    for _, sub in pairs( subtable ) do
      --if sub.nextevent then
      --  self:F2( "nextevent = " .. sub.nextevent )
      --  self[sub.nextevent]( self )
      --end
      self:F2( "calling sub: " .. sub.event )
      sub.fsm.fsmparent = self
      sub.fsm.ReturnEvents = sub.ReturnEvents
      sub.fsm[sub.event]( sub.fsm )
      execute = true
    end

    local fsmparent, event = self:_isendstate( to )
    if fsmparent and event then
      self:F2( { "end state: ", fsmparent, event } )
      self:_call_handler(self["onenter" .. to] or self["on" .. to], params)
      self:_call_handler(self["onafter" .. EventName] or self["on" .. EventName], params)
      self:_call_handler(self["onstatechange"], params)
      fsmparent[event]( fsmparent )
      execute = false
    end

    if execute then
      self:T3( { onenter = "onenter" .. to, callback = self["onenter" .. to] }  )
      self:_call_handler(self["onenter" .. to] or self["on" .. to], params)

      self:T3( { On = "OnBefore" .. to, callback = self["OnBefore" .. to] }  )
      if ( self:_call_handler(self["OnBefore" .. to], params ) ~= false ) then

        self:T3( { onafter = "onafter" .. EventName, callback = self["onafter" .. EventName] }  )
        self:_call_handler(self["onafter" .. EventName] or self["on" .. EventName], params)

        self:T3( { On = "OnAfter" .. to, callback = self["OnAfter" .. to] }  )
        ReturnValues = self:_call_handler(self["OnAfter" .. to], params )
      end

      self:_call_handler(self["onstatechange"], params)
    end

    return ReturnValues
  end

  return nil
end

function STATEMACHINE:_delayed_transition( EventName )
  self:E( { EventName = EventName } )
  return function( self, DelaySeconds, ... )
    self:T( "Delayed Event: " .. EventName )
    SCHEDULER:New( self, self._handler, { EventName, ... }, DelaySeconds )
  end
end

function STATEMACHINE:_create_transition( EventName )
  self:E( { Event =  EventName  } )
  return function( self, ... ) return self._handler( self,  EventName , ... ) end
end

function STATEMACHINE:_gosub( ParentFrom, ParentEvent )
  local fsmtable = {}
  self:E( { ParentFrom, ParentEvent, self.subs[ParentFrom] } )
  if self.subs[ParentFrom] and self.subs[ParentFrom][ParentEvent] then
    return self.subs[ParentFrom][ParentEvent]
  else
    return {}
  end
end

function STATEMACHINE:_isendstate( Current )
  local FSMParent = self.fsmparent
  if FSMParent and self.endstates[Current] then
    self:E( { state = Current, endstates = self.endstates, endstate = self.endstates[Current] } )
    FSMParent.current = Current
    local ParentFrom = FSMParent.current
    self:E( ParentFrom )
    self:E( self.ReturnEvents )
    local Event = self.ReturnEvents[Current]
    self:E( { ParentFrom, Event, self.ReturnEvents } )
    if Event then
      return FSMParent, Event
    else
      self:E( { "Could not find parent event name for state ", ParentFrom } )
    end
  end

  return nil
end

function STATEMACHINE:_add_to_map(map, event)
  self:E( { map, event } )
  if type(event.from) == 'string' then
    map[event.from] = event.to
  else
    for _, from in ipairs(event.from) do
      map[from] = event.to
    end
  end
  self:E( { map, event } )
end

function STATEMACHINE:is(state)
  return self.current == state
end

function STATEMACHINE:can(e)
  local event = self.events[e]
  self:E( { self.current, event } )
  local to = event and event.map[self.current] or event.map['*']
  return to ~= nil, to
end

function STATEMACHINE:cannot(e)
  return not self:can(e)
end

function STATEMACHINE:todot(filename)
  local dotfile = io.open(filename,'w')
  dotfile:write('digraph {\n')
  local transition = function(event,from,to)
    dotfile:write(string.format('%s -> %s [label=%s];\n',from,to,event))
  end
  for _, event in pairs(self.options.events) do
    if type(event.from) == 'table' then
      for _, from in ipairs(event.from) do
        transition(event.name,from,event.to)
      end
    else
      transition(event.name,event.from,event.to)
    end
  end
  dotfile:write('}\n')
  dotfile:close()
end


--- STATEMACHINE_TASK class
-- @type STATEMACHINE_TASK
-- @field Task#TASK_BASE Task
-- @extends StateMachine#STATEMACHINE
STATEMACHINE_TASK = {
  ClassName = "STATEMACHINE_TASK",
}

--- Creates a new STATEMACHINE_TASK object.
-- @param #STATEMACHINE_TASK self
-- @param #table FSMT
-- @param Task#TASK_BASE Task
-- @param Unit#UNIT TaskUnit
-- @return #STATEMACHINE_TASK
function STATEMACHINE_TASK:New( FSMT, Task, TaskUnit )

  local self = BASE:Inherit( self, STATEMACHINE:New( FSMT ) ) -- StateMachine#STATEMACHINE_PROCESS

  self["onstatechange"] = Task.OnStateChange
  self["onAssigned"] = Task.OnAssigned
  self["onSuccess"] = Task.OnSuccess
  self["onFailed"] = Task.OnFailed

  self.Task = Task
  self.TaskUnit = TaskUnit

  return self
end

function STATEMACHINE_TASK:_call_handler( handler, params )
  if handler then
    return handler( self.Task, self.TaskUnit, unpack( params ) )
  end
end

--- STATEMACHINE_CONTROLLABLE class
-- @type STATEMACHINE_CONTROLLABLE
-- @field Controllable#CONTROLLABLE Controllable
-- @extends Core.StateMachine#STATEMACHINE
STATEMACHINE_CONTROLLABLE = {
  ClassName = "STATEMACHINE_CONTROLLABLE",
}

--- Creates a new STATEMACHINE_CONTROLLABLE object.
-- @param #STATEMACHINE_CONTROLLABLE self
-- @param #table FSMT Finite State Machine Table
-- @param Controllable#CONTROLLABLE Controllable (optional) The CONTROLLABLE object that the STATEMACHINE_CONTROLLABLE governs.
-- @return #STATEMACHINE_CONTROLLABLE
function STATEMACHINE_CONTROLLABLE:New( FSMT, Controllable )

  -- Inherits from BASE
  local self = BASE:Inherit( self, STATEMACHINE:New( FSMT ) ) -- StateMachine#STATEMACHINE_CONTROLLABLE

  if Controllable then
    self:SetControllable( Controllable )
  end

  return self
end

--- Sets the CONTROLLABLE object that the STATEMACHINE_CONTROLLABLE governs.
-- @param #STATEMACHINE_CONTROLLABLE self
-- @param Controllable#CONTROLLABLE FSMControllable
-- @return #STATEMACHINE_CONTROLLABLE
function STATEMACHINE_CONTROLLABLE:SetControllable( FSMControllable )
  self:F( FSMControllable )
  self.Controllable = FSMControllable
end

--- Gets the CONTROLLABLE object that the STATEMACHINE_CONTROLLABLE governs.
-- @param #STATEMACHINE_CONTROLLABLE self
-- @return Controllable#CONTROLLABLE
function STATEMACHINE_CONTROLLABLE:GetControllable()
  return self.Controllable
end

function STATEMACHINE_CONTROLLABLE:_call_handler( handler, params )
  if handler then
    return handler( self, self.Controllable, unpack( params ) )
  end
end

--- STATEMACHINE_PROCESS class
-- @type STATEMACHINE_PROCESS
-- @field Process#PROCESS Process
-- @extends Core.StateMachine#STATEMACHINE_CONTROLLABLE
STATEMACHINE_PROCESS = {
  ClassName = "STATEMACHINE_PROCESS",
}

--- Creates a new STATEMACHINE_PROCESS object.
-- @param #STATEMACHINE_PROCESS self
-- @return #STATEMACHINE_PROCESS
function STATEMACHINE_PROCESS:New( FSMT )

  local self = BASE:Inherit( self, STATEMACHINE_CONTROLLABLE:New( FSMT ) ) -- StateMachine#STATEMACHINE_PROCESS

  return self
end

do -- STATEMACHINE_SET

--- STATEMACHINE_SET class
-- @type STATEMACHINE_SET
-- @field Set#SET_BASE Set
-- @extends StateMachine#STATEMACHINE
STATEMACHINE_SET = {
  ClassName = "STATEMACHINE_SET",
}

--- Creates a new STATEMACHINE_SET object.
-- @param #STATEMACHINE_SET self
-- @param #table FSMT Finite State Machine Table
-- @param Set_SET_BASE FSMSet (optional) The Set object that the STATEMACHINE_SET governs.
-- @return #STATEMACHINE_SET
function STATEMACHINE_SET:New( FSMT, FSMSet )

  -- Inherits from BASE
  local self = BASE:Inherit( self, STATEMACHINE:New( FSMT ) ) -- StateMachine#STATEMACHINE_SET

  if FSMSet then
    self:Set( FSMSet )
  end

  return self
end

--- Sets the SET_BASE object that the STATEMACHINE_SET governs.
-- @param #STATEMACHINE_SET self
-- @param Set#SET_BASE FSMSet
-- @return #STATEMACHINE_SET
function STATEMACHINE_SET:Set( FSMSet )
  self:F( FSMSet )
  self.Set = FSMSet
end

--- Gets the SET_BASE object that the STATEMACHINE_SET governs.
-- @param #STATEMACHINE_SET self
-- @return Set#SET_BASE
function STATEMACHINE_SET:Get()
  return self.Controllable
end

function STATEMACHINE_SET:_call_handler( handler, params )
  if handler then
    return handler( self, self.Set, unpack( params ) )
  end
end

end
