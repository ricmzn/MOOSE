--- **AI (Release 2.1)** -- Management of target designation.
--
-- --![Banner Image](..\Presentations\DESIGNATE\Dia1.JPG)
--
-- ===
--
-- @module AI_Designate


do -- AI_DESIGNATE

  --- @type AI_DESIGNATE
  -- @extends Core.Fsm#FSM_PROCESS

  --- # AI_DESIGNATE class, extends @{Fsm#FSM}
  -- 
  -- AI_DESIGNATE is orchestrating the designation of potential targets executed by a Recce group, 
  -- and communicates these to a dedicated attacking group of players, 
  -- so that following a dynamically generated menu system, 
  -- each detected set of potential targets can be lased or smoked...
  -- 
  -- Targets can be:
  -- 
  --   * **Lased** for a period of time.
  --   * **Smoked**. Artillery or airplanes with Illuminatino ordonance need to be present. (WIP, but early demo ready.)
  --   * **Illuminated** through an illumination bomb. Artillery or airplanes with Illuminatino ordonance need to be present. (WIP, but early demo ready.
  -- 
  -- The following terminology is being used throughout this document:
  -- 
  --   * The **DesignateObject** is the object of the AI_DESIGNATE class, which is this class explained in the document.
  --   * The **DetectionObject** is the object of a DETECTION_ class (DETECTION_TYPES, DETECTION_AREAS, DETECTION_UNITS), which is executing the detection and grouping of Targets into _DetectionItems_.
  --   * **DetectionItems** is the list of detected target groupings by the _DetectionObject_. Each _DetectionItem_ contains a _TargetSet_.
  --   * **DetectionItem** is one element of the _DetectionItems_ list, and contains a _TargetSet_.
  --   * The **TargetSet** is a SET_UNITS collection of _Targets_, that have been detected by the _DetectionObject_.
  --   * A **Target** is a detected UNIT object by the _DetectionObject_.
  --   * A **Threat Level** is a number from 0 to 10 that is calculated based on the threat of the Target in an Air to Ground battle scenario.
  --   * The **RecceSet** is a SET_GROUP collection that contains the **RecceGroups**.
  --   * A **RecceGroup** is a GROUP object containing the **Recces**.
  --   * A **Recce** is a UNIT object executing the reconnaissance as part the _DetectionObject_. A Recce can be of any UNIT type.
  --   * An **AttackGroup** is a GROUP object that contain _Players_.
  --   * A **Player** is an active CLIENT object containing a human player.
  --   * A **Designate Menu** is the menu that is dynamically created during the designation process for each _AttackGroup_.
  -- 
  -- The _RecceSet_ is continuously detecting for potential _Targets_, executing its task as part of the _DetectionObject_.
  -- Once _Targets_ have been detected, the _DesignateObject_ will trigger the **Detect Event**.
  -- 
  -- As part of the Detect Event, the _DetectionItems_ list is used by the _DesignateObject_ to provide the _Players_ with:
  -- 
  --   * The _RecceGroups_ are reporting to each _AttackGroup_, sending **Messages** containing the _Threat Level_ and the _TargetSet_ composition.
  --   * **Menu options** are created and updated for each _AttackGroup_, containing the _Threat Level_ and the _TargetSet_ composition.
  -- 
  -- A _Player_ can then select an action from the _Designate Menu_. 
  -- 
  -- **Note that each selected action will be executed for a _TargetSet_, thus the _Target_ grouping done by the _DetectionObject_.**
  -- 
  -- Each **Menu Option** in the _Designate Menu_ has two modes: 
  -- 
  --   1. If the _TargetSet_ **is not being designated**, then the **Designate Menu** option for the target Set will provide options to **Lase** or **Smoke** the targets.
  --   2. If the Target Set **is being designated**, then the **Designate Menu** option will provide an option to stop or cancel the designation.
  -- 
  -- While designating, the _RecceGroups_ will report any change in _TargetSet_ composition or _Target_ presence.
  -- 
  -- The following logic is executed when a _TargetSet_ is selected to be *lased* from the _Designation Menu_:
  -- 
  --   * The _RecceSet_ is searched for any _Recce_ that is within *designation distance* from a _Target_ in the _TargetSet_ that is currently not being designated.
  --   * If there is a _Recce_ found that is currently no designating a target, and is within designation distance from the _Target_, then that _Target_ will be designated.
  --   * During designation, any _Recce_ that does not have Line of Sight (LOS) and is not within disignation distance from the _Target_, will stop designating the _Target_, and a report is given.
  --   * When a _Recce_ is designating a _Target_, and that _Target_ is destroyed, then the _Recce_ will stop designating the _Target_, and will report the event.
  --   * When a _Recce_ is designating a _Target_, and that _Recce_ is destroyed, then the _Recce_ will be removed from the _RecceSet_ and designation will stop without reporting.
  --   * When all _RecceGroups_ are destroyed from the _RecceSet_, then the DesignationObject will stop functioning, and nothing will be reported.
  --   
  -- In this way, the DesignationObject assists players to designate ground targets for a coordinated attack!
  -- 
  -- Have FUN!
  -- 
  -- ## 1. AI_DESIGNATE constructor
  --   
  --   * @{#AI_DESIGNATE.New}(): Creates a new AI_DESIGNATE object.
  -- 
  -- ## 2. AI_DESIGNATE is a FSM
  -- 
  -- ![Process](�)
  -- 
  -- ### 2.1 AI_DESIGNATE States
  -- 
  --   * **Designating** ( Group ): The process is not started yet.
  -- 
  -- ### 2.2 AI_DESIGNATE Events
  -- 
  --   * **@{#AI_DESIGNATE.Detect}**: Detect targets.
  --   * **@{#AI_DESIGNATE.LaseOn}**: Lase the targets with the specified Index.
  --   * **@{#AI_DESIGNATE.LaseOff}**: Stop lasing the targets with the specified Index.
  --   * **@{#AI_DESIGNATE.Smoke}**: Smoke the targets with the specified Index.
  --   * **@{#AI_DESIGNATE.Status}**: Report designation status.
  -- 
  -- ## 3. Set laser codes
  -- 
  -- An array of laser codes can be provided, that will be used by the AI_DESIGNATE when lasing.
  -- The laser code is communicated by the Recce when it is lasing a larget.
  -- Note that the default laser code is 1113.
  -- Working known laser codes are: 1113,1462,1483,1537,1362,1214,1131,1182,1644,1614,1515,1411,1621,1138,1542,1678,1573,1314,1643,1257,1467,1375,1341,1275,1237
  -- 
  -- Use the method @{#AI_DESIGNATE.SetLaserCodes}() to set the possible laser codes to be selected from.
  -- One laser code can be given or an sequence of laser codes through an table...
  -- 
  --     AIDesignate:SetLaserCodes( 1214 )
  --     
  -- The above sets one laser code with the value 1214.
  -- 
  --     AIDesignate:SetLaserCodes( { 1214, 1131, 1614, 1138 } )
  --     
  -- The above sets a collection of possible laser codes that can be assigned. **Note the { } notation!**
  -- 
  -- 
  -- 
  -- @field #AI_DESIGNATE
  -- 
  AI_DESIGNATE = {
    ClassName = "AI_DESIGNATE",
  }

  --- AI_DESIGNATE Constructor. This class is an abstract class and should not be instantiated.
  -- @param #AI_DESIGNATE self
  -- @param Functional.Detection#DETECTION_BASE Detection
  -- @param Core.Set#SET_GROUP GroupSet The set of groups to designate for.
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:New( Detection, GroupSet )
  
    local self = BASE:Inherit( self, FSM:New() ) -- #AI_DESIGNATE
    self:F( { Detection } )
  
    self:SetStartState( "Designating" )
    self:AddTransition( "*", "Detect", "*" )
    
    --- Detect Handler OnBefore for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] OnBeforeDetect
    -- @param #AI_DESIGNATE self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    -- @return #boolean
    
    --- Detect Handler OnAfter for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] OnAfterDetect
    -- @param #AI_DESIGNATE self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    
    --- Detect Trigger for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] Detect
    -- @param #AI_DESIGNATE self
    
    --- Detect Asynchronous Trigger for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] __Detect
    -- @param #AI_DESIGNATE self
    -- @param #number Delay
    
    

    self:AddTransition( "*", "LaseOn", "Lasing" )
    
    --- LaseOn Handler OnBefore for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnBeforeLaseOn
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    -- @return #boolean
    
    --- LaseOn Handler OnAfter for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnAfterLaseOn
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    
    --- LaseOn Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] LaseOn
    -- @param #AI_DESIGNATE  self
    
    --- LaseOn Asynchronous Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] __LaseOn
    -- @param #AI_DESIGNATE  self
    -- @param #number Delay
    
    self:AddTransition( "Lasing", "Lasing", "Lasing" )
    
    self:AddTransition( "*", "LaseOff", "Designate" )
    
    --- LaseOff Handler OnBefore for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnBeforeLaseOff
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    -- @return #boolean
    
    --- LaseOff Handler OnAfter for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnAfterLaseOff
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    
    --- LaseOff Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] LaseOff
    -- @param #AI_DESIGNATE  self
    
    --- LaseOff Asynchronous Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] __LaseOff
    -- @param #AI_DESIGNATE  self
    -- @param #number Delay
    
    
    
    self:AddTransition( "*", "Smoke", "*" )
    
    --- Smoke Handler OnBefore for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnBeforeSmoke
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    -- @return #boolean
    
    --- Smoke Handler OnAfter for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnAfterSmoke
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    
    --- Smoke Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] Smoke
    -- @param #AI_DESIGNATE  self
    
    --- Smoke Asynchronous Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] __Smoke
    -- @param #AI_DESIGNATE  self
    -- @param #number Delay
    
    self:AddTransition( "*", "Illuminate", "*" )
    
    --- Illuminate Handler OnBefore for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] OnBeforeIlluminate
    -- @param #AI_DESIGNATE self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    -- @return #boolean
    
    --- Illuminate Handler OnAfter for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] OnAfterIlluminate
    -- @param #AI_DESIGNATE self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    
    --- Illuminate Trigger for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] Illuminate
    -- @param #AI_DESIGNATE self
    
    --- Illuminate Asynchronous Trigger for AI_DESIGNATE
    -- @function [parent=#AI_DESIGNATE] __Illuminate
    -- @param #AI_DESIGNATE self
    -- @param #number Delay

    self:AddTransition( "*", "Done", "*" )
    
    self:AddTransition( "*", "Status", "*" )
    
    --- Status Handler OnBefore for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnBeforeStatus
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    -- @return #boolean
    
    --- Status Handler OnAfter for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] OnAfterStatus
    -- @param #AI_DESIGNATE  self
    -- @param #string From
    -- @param #string Event
    -- @param #string To
    
    --- Status Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] Status
    -- @param #AI_DESIGNATE  self
    
    --- Status Asynchronous Trigger for AI_DESIGNATE 
    -- @function [parent=#AI_DESIGNATE ] __Status
    -- @param #AI_DESIGNATE  self
    -- @param #number Delay
    
    self.Detection = Detection
    self.GroupSet = GroupSet
    self.RecceSet = Detection:GetDetectionSetGroup()
    self.Spots = {}
    self.Designating = {}
    
    self:SetLaserCodes( 1688 )
    
    self.LaserCodesUsed = {}
    
    
    self.Detection:__Start( 2 )

    
    return self
  end
  

  --- Set an array of possible laser codes.
  -- Each new lase will select a code from this table.
  -- @param #AI_DESIGNATE self
  -- @param #list<#number> LaserCodes
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:SetLaserCodes( LaserCodes )

    self.LaserCodes = ( type( LaserCodes ) == "table" ) and LaserCodes or { LaserCodes }
    self:E(self.LaserCodes)
    
    self.LaserCodesUsed = {}

    return self
  end
  

  --- 
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterDetect()
    
    self:__Detect( -60 )
    
    self:SendStatus()
    self:SetDesignateMenu()      
  
    return self
  end

  --- Sends the status to the Attack Groups.
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:SendStatus()

    local DetectedReport = REPORT:New( "Targets ready to be designated:" )
    local DetectedItems = self.Detection:GetDetectedItems()
    
    for Index, DetectedItemData in pairs( DetectedItems ) do
      
      local Report = self.Detection:DetectedItemReportSummary( Index )
      DetectedReport:Add(" - " .. Report)
    end
    
    local RecceLeader = self.RecceSet:GetFirst() -- Wrapper.Group#GROUP

    self.GroupSet:ForEachGroup(
    
      --- @param Wrapper.Group#GROUP GroupReport
      function( AttackGroup )
        RecceLeader:MessageToGroup( DetectedReport:Text( "\n" ), 15, AttackGroup )
      end
    )
    
    return self
  end

  --- Sets the Designate Menu.
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:SetDesignateMenu()

    self.GroupSet:Flush()

    self.GroupSet:ForEachGroup(
    
      --- @param Wrapper.Group#GROUP GroupReport
      function( AttackGroup )
        local DesignateMenu = AttackGroup:GetState( AttackGroup, "DesignateMenu" ) -- Core.Menu#MENU_GROUP
        if DesignateMenu then
          DesignateMenu:Remove()
          DesignateMenu = nil
          self:E("Remove Menu")
        end
        DesignateMenu = MENU_GROUP:New( AttackGroup, "Designate" )
        self:E(DesignateMenu)
        AttackGroup:SetState( AttackGroup, "DesignateMenu", DesignateMenu )
        
      
        local DetectedItems = self.Detection:GetDetectedItems()
        
        for Index, DetectedItemData in pairs( DetectedItems ) do
          
          local Report = self.Detection:DetectedItemReportSummary( Index )
          
          if not self.Designating[Index] then
            local DetectedMenu = MENU_GROUP:New( AttackGroup, Report, DesignateMenu )
            MENU_GROUP_COMMAND:New( AttackGroup, "Lase target 60 secs", DetectedMenu, self.MenuLaseOn, self, AttackGroup, Index, 60 )
            MENU_GROUP_COMMAND:New( AttackGroup, "Lase target 120 secs", DetectedMenu, self.MenuLaseOn, self,AttackGroup, Index, 120 )
            MENU_GROUP_COMMAND:New( AttackGroup, "Smoke red", DetectedMenu, self.MenuSmoke, self, AttackGroup, Index, SMOKECOLOR.Red )
            MENU_GROUP_COMMAND:New( AttackGroup, "Smoke blue", DetectedMenu, self.MenuSmoke, self, AttackGroup, Index, SMOKECOLOR.Blue )
            MENU_GROUP_COMMAND:New( AttackGroup, "Smoke green", DetectedMenu, self.MenuSmoke, self, AttackGroup, Index, SMOKECOLOR.Green )
            MENU_GROUP_COMMAND:New( AttackGroup, "Smoke white", DetectedMenu, self.MenuSmoke, self, AttackGroup, Index, SMOKECOLOR.White )
            MENU_GROUP_COMMAND:New( AttackGroup, "Smoke orange", DetectedMenu, self.MenuSmoke, self, AttackGroup, Index, SMOKECOLOR.Orange )
            MENU_GROUP_COMMAND:New( AttackGroup, "Illuminate", DetectedMenu, self.MenuIlluminate, self, AttackGroup, Index )
          else
            if self.Designating[Index] == "Laser" then
              Report = "Lasing " .. Report
            elseif self.Designating[Index] == "Smoke" then
              Report = "Smoking " .. Report
            elseif self.Designating[Index] == "Illuminate" then
              Report = "Illuminating " .. Report
            end
            local DetectedMenu = MENU_GROUP:New( AttackGroup, Report, DesignateMenu )
            if self.Designating[Index] == "Laser" then
              MENU_GROUP_COMMAND:New( AttackGroup, "Stop lasing", DetectedMenu, self.MenuLaseOff, self, AttackGroup, Index )
            else
            end
          end
        end
      end
    )
    
    return self
  end
  
  --- 
  -- @param #AI_DESIGNATE self
  function AI_DESIGNATE:MenuSmoke( AttackGroup, Index, Color )

    self:E("Designate through Smoke")

    self.Designating[Index] = "Smoke"
    self:__Smoke( 1, AttackGroup, Index, Color )    
  end

  --- 
  -- @param #AI_DESIGNATE self
  function AI_DESIGNATE:MenuIlluminate( AttackGroup, Index )

    self:E("Designate through Illumination")

    self.Designating[Index] = "Illuminate"
    
    self:__Illuminate( 1, AttackGroup, Index )
  end

  --- 
  -- @param #AI_DESIGNATE self
  function AI_DESIGNATE:MenuLaseOn( AttackGroup, Index, Duration )

    self:E("Designate through Lase")
    
    self.Designating[Index] = "Laser"
    self:__LaseOn( 1, AttackGroup, Index, Duration ) 
  end

  --- 
  -- @param #AI_DESIGNATE self
  function AI_DESIGNATE:MenuLaseOff( AttackGroup, Index, Duration )

    self:E("Lasing off")

    self.Designating[Index] = nil
    self:__LaseOff( 1, AttackGroup, Index ) 
  end

  --- 
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterLaseOn( From, Event, To, AttackGroup, Index, Duration )
  
    self:__Lasing( 5, AttackGroup, Index, Duration )
  
  end
  

  --- 
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterLasing( From, Event, To, AttackGroup, Index, Duration )
  
    local TargetSetUnit = self.Detection:GetDetectedSet( Index )
    
    TargetSetUnit:Flush()

    for TargetUnit, SpotData in pairs( self.Spots ) do
      local Spot = SpotData -- Core.Spot#SPOT
      if not Spot:IsLasing() then
        local LaserCode = Spot.LaserCode --(Not deleted when stopping with lasing).
        self.LaserCodesUsed[LaserCode] = nil
        self.Spots[TargetUnit] = nil
      end
    end

    local MoreTargets = false

    TargetSetUnit:ForEachUnit(
      --- @param Wrapper.Unit#UNIT SmokeUnit
      function( TargetUnit )
        self:E("In procedure")
        if TargetUnit:IsAlive() then
          local Spot = self.Spots[TargetUnit]
          if (not Spot) or ( Spot and Spot:IsLasing() == false ) then
            for RecceGroupID, RecceGroup in pairs( self.RecceSet:GetSet() ) do
              for UnitID, UnitData in pairs( RecceGroup:GetUnits() or {} ) do
                local RecceUnit = UnitData -- Wrapper.Unit#UNIT
                if RecceUnit:IsLasing() == false then
                  if RecceUnit:IsDetected( TargetUnit ) and RecceUnit:IsLOS( TargetUnit ) then
                    local LaserCodeIndex = math.random( 1, #self.LaserCodes )
                    local LaserCode = self.LaserCodes[LaserCodeIndex]
                    if not self.LaserCodesUsed[LaserCode] then
                      MoreTargets = true
                      self.LaserCodesUsed[LaserCode] = LaserCodeIndex
                      local Spot = RecceUnit:LaseUnit( TargetUnit, LaserCode, Duration )
                      function Spot:OnAfterDestroyed( From, Event, To )
                        self:E( "Destroyed Message" )
                        self.Recce:MessageToGroup( "Target " .. TargetUnit:GetTypeName() .. " destroyed." .. TargetSetUnit:Count() .. " targets left.", 5, AttackGroup )
                      end
                      self.Spots[TargetUnit] = Spot
                      RecceUnit:MessageToGroup( "Lasing " .. TargetUnit:GetTypeName() .. " for " .. Duration .. "s, code: " .. Spot.LaserCode, 5, AttackGroup )
                      break
                    end
                  end
                else
                  -- The Recce is lasing, but the Target is not detected or within LOS. So stop lasing and send a report.
                  if not RecceUnit:IsDetected( TargetUnit ) or not RecceUnit:IsLOS( TargetUnit ) then
                    local Spot = self.Spots[TargetUnit] -- Core.Spot#SPOT
                    if Spot then
                      Spot.Recce:LaseOff()
                      Spot.Recce:MessageToGroup( "Target " .. TargetUnit:GetTypeName() "out of LOS. Cancelling lase!", 5, AttackGroup )
                    end
                  end  
                end
              end
            end
          else
            MoreTargets = true
            local RecceUnit = Spot.Recce
            RecceUnit:MessageToGroup( "Lasing " .. TargetUnit:GetTypeName() .. ", code " .. Spot.LaserCode, 5, AttackGroup )
          end
        else
          self.Spots[TargetUnit] = nil
        end
      end
    )

    if MoreTargets == true then
      self:__Lasing( 30, AttackGroup, Index, Duration )
    else
      self:__LaseOff( 1, AttackGroup, Index ) 
    end
    
    self:SetDesignateMenu()

  end
    
  --- 
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterLaseOff( From, Event, To, AttackGroup, Index )
  
    self.RecceSet:GetFirst():MessageToGroup( "Stopped lasing.", 15, AttackGroup )
    
    local TargetSetUnit = self.Detection:GetDetectedSet( Index )
    
    local Spots = self.Spots
    
    for SpotID, SpotData in pairs( Spots ) do
      local Spot = SpotData -- Core.Spot#SPOT
      Spot.Recce:MessageToGroup( "Stopped lasing " .. Spot.Target:GetTypeName() .. ".", 15, AttackGroup )
      Spot:LaseOff()
    end
    
    Spots = nil
    self.Spots = {}
    self.LaserCodesUsed = {}

    self:SetDesignateMenu()
  end


  --- 
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterSmoke( From, Event, To, AttackGroup, Index, Color )
  

    local TargetSetUnit = self.Detection:GetDetectedSet( Index )
    local TargetSetUnitCount = TargetSetUnit:Count()
  
    TargetSetUnit:ForEachUnit(
      --- @param Wrapper.Unit#UNIT SmokeUnit
      function( SmokeUnit )
        self:E("In procedure")
        if math.random( 1, TargetSetUnitCount ) == math.random( 1, TargetSetUnitCount ) then
          local RecceGroup = self.RecceSet:FindNearestGroupFromPointVec2(SmokeUnit:GetPointVec2())
          local RecceUnit = RecceGroup:GetUnit( 1 )
          RecceUnit:MessageToGroup( "Smoking " .. SmokeUnit:GetTypeName() .. ".", 5, AttackGroup )
          SCHEDULER:New( self,
            function()
              if SmokeUnit:IsAlive() then
                SmokeUnit:Smoke( Color, 150 )
              end
            self:Done( Index )
            end, {}, math.random( 5, 20 ) 
          )
        end
      end
    )
    

  end

  --- Illuminating
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterIlluminate( From, Event, To, AttackGroup, Index )
  
    local TargetSetUnit = self.Detection:GetDetectedSet( Index )
    
    local TargetUnit = TargetSetUnit:GetFirst()
  
    if TargetUnit then
        local RecceGroup = self.RecceSet:FindNearestGroupFromPointVec2(TargetUnit:GetPointVec2())
        local RecceUnit = RecceGroup:GetUnit( 1 )
        RecceUnit:MessageToGroup( "Illuminating " .. TargetUnit:GetTypeName() .. ".", 5, AttackGroup )
        SCHEDULER:New( self,
          function()
            if TargetUnit:IsAlive() then
              TargetUnit:GetPointVec3():AddY(300):IlluminationBomb()
            end
          self:Done( Index )
          end, {}, math.random( 5, 20 ) 
        )
    end
  end

  --- Done
  -- @param #AI_DESIGNATE self
  -- @return #AI_DESIGNATE
  function AI_DESIGNATE:onafterDone( From, Event, To, Index )

    self.Designating[Index] = nil
    self:SetDesignateMenu()
  end

end


