require "Window"
require "ApolloTimer"

local VikingClassResources = {
  _VERSION = 'VikingClassResources.lua 0.2.0',
  _URL     = 'https://github.com/vikinghug/VikingClassResources',
  _DESCRIPTION = '',
  _LICENSE = [[
    MIT LICENSE

    Copyright (c) 2014 Kevin Altman

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]
}

-- GameLib.CodeEnumClass.Warrior      = 1
-- GameLib.CodeEnumClass.Engineer     = 2
-- GameLib.CodeEnumClass.Esper        = 3
-- GameLib.CodeEnumClass.Medic        = 4
-- GameLib.CodeEnumClass.Stalker      = 5
-- GameLib.CodeEnumClass.Spellslinger = 7

 local tClassName = {
  [GameLib.CodeEnumClass.Warrior]      = "Warrior",
  [GameLib.CodeEnumClass.Engineer]     = "Engineer",
  [GameLib.CodeEnumClass.Esper]        = "Esper",
  [GameLib.CodeEnumClass.Medic]        = "Medic",
  [GameLib.CodeEnumClass.Stalker]      = "Stalker",
  [GameLib.CodeEnumClass.Spellslinger] = "Spellslinger"
}

local tResourceType = {
  [GameLib.CodeEnumClass.Warrior]      = 1,
  [GameLib.CodeEnumClass.Engineer]     = 1,
  [GameLib.CodeEnumClass.Esper]        = 1,
  [GameLib.CodeEnumClass.Medic]        = 1,
  [GameLib.CodeEnumClass.Stalker]      = 3,
  [GameLib.CodeEnumClass.Spellslinger] = 4
}

local tInnateTime = {
  [GameLib.CodeEnumClass.Warrior]      = 8,
  [GameLib.CodeEnumClass.Engineer]     = 10.5,
  [GameLib.CodeEnumClass.Esper]        = 0,
  [GameLib.CodeEnumClass.Medic]        = 0,
  [GameLib.CodeEnumClass.Stalker]      = 0,
  [GameLib.CodeEnumClass.Spellslinger] = 0
}

function VikingClassResources:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function VikingClassResources:Init()
  Apollo.RegisterAddon(self, nil, nil, {"VikingActionBarFrame"})
end

function VikingClassResources:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("VikingClassResources.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)

  Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)


  Apollo.LoadSprites("VikingClassResourcesSprites.xml")
end

function VikingClassResources:OnDocumentReady()
  if self.xmlDoc == nil then
    return
  end

  self.bDocLoaded = true
  self:OnRequiredFlagsChanged()
end

function VikingClassResources:OnRequiredFlagsChanged()
  if g_wndActionBarResources and self.bDocLoaded then
    if GameLib.GetPlayerUnit() then
      self:OnCharacterCreated()
    else
      Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
    end
  end
end


function VikingClassResources:OnCharacterCreated()
  local unitPlayer = GameLib.GetPlayerUnit()
  if not unitPlayer then
    return
  end

  self.eClassID =  unitPlayer:GetClassId()

  self:CreateClassResources()

end


function VikingClassResources:CreateClassResources()

  Apollo.RegisterEventHandler("VarChange_FrameCount",     "OnUpdateTimer", self)
  Apollo.RegisterEventHandler("UnitEnteredCombat",        "OnEnteredCombat", self)
  Apollo.RegisterTimerHandler("OutOfCombatFade",          "OnOutOfCombatFade", self)

  self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingClassResourceForm", g_wndActionBarResources, self)
  self.wndMain:ToFront()
end


function VikingClassResources:ResizeResourceNodes(nResourceMax)
  local nOffsets = {}
  nOffsets.nOL, nOffsets.nOT, nOffsets.nOR, nOffsets.nOB = self.wndMain:GetAnchorOffsets()

  local nWidth = (nOffsets.nOR - nOffsets.nOL) / nResourceMax

  for i = 1, nResourceMax do
    local p       = i-1
    local wndNode = self.wndMain:FindChild("Node" .. i)
    wndNode:SetAnchorPoints(0, 0, 0, 1)
    wndNode:SetAnchorOffsets(nWidth * p, 0, nWidth * i, 0)
  end

end

function VikingClassResources:OnUpdateTimer()
  local unitPlayer = GameLib.GetPlayerUnit()
  local className  = tClassName[self.eClassID]
  local resourceID = tResourceType[self.eClassID]


  local nResourceMax     = unitPlayer:GetMaxResource(resourceID)
  local nResourceCurrent = unitPlayer:GetResource(resourceID)
  self["Update" .. className .. "Resources"](self, unitPlayer, nResourceMax, nResourceCurrent)

end


function VikingClassResources:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)
  local wndPrimaryProgress = self.wndMain:FindChild("PrimaryProgressBar")
  local nProgressCurrent   = nResourceCurrent and nResourceCurrent or math.floor(unitPlayer:GetMana())
  local nProgressMax       = nResourceMax and nResourceMax or math.floor(unitPlayer:GetMaxMana())
  local className          = tClassName[self.eClassID]

  wndPrimaryProgress:SetMax(nProgressMax)
  wndPrimaryProgress:SetProgress(nProgressCurrent)
  wndPrimaryProgress:SetTooltip(String_GetWeaselString(Apollo.GetString( className .. "Resource_FocusTooltip" ), nProgressCurrent, nProgressMax))
  self.wndMain:FindChild("PrimaryProgressText"):SetText(nProgressCurrent == nProgressMax and "" or (math.floor(nProgressCurrent / nProgressMax * 100).."%"))

end


--
-- WARRIOR


function VikingClassResources:UpdateWarriorResources(unitPlayer, nResourceMax, nResourceCurrent)
  local bInnate              = GameLib.IsOverdriveActive()
  local wndPrimaryProgress   = self.wndMain:FindChild("PrimaryProgressBar")
  local wndSecondaryProgress = self.wndMain:FindChild("SecondaryProgressBar")
  local unitPlayer           = GameLib.GetPlayerUnit()

  -- Primary Resource
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)
  wndPrimaryProgress:Show(not self.bInnateActive)

  -- Innate Bar
  wndSecondaryProgress:Show(self.bInnateActive)
  self:UpdateInnateProgress(bInnate)

  -- Innate State Indicator
  self.wndMain:FindChild("InnateGlow"):Show(bInnate)

end


--
-- ENGINEER

function VikingClassResources:UpdateEngineerResources(unitPlayer, nResourceMax, nResourceCurrent)
  local bInnate              = GameLib.IsCurrentInnateAbilityActive()
  local wndSecondaryProgress = self.wndMain:FindChild("SecondaryProgressBar")

  -- Primary Resource
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)

  -- Innate Bar
  self:UpdateInnateProgress(bInnate)

  -- Innate State Indicator
  self:ShowInnateIndicator(bInnate)

end

--
-- ESPER

function VikingClassResources:UpdateEsperResources(unitPlayer, nResourceMax, nResourceCurrent)

  -- Primary Resource (Psi Points)
  self:ResizeResourceNodes(nResourceMax)

  for i = 1, nResourceMax do
    local nShow = nResourceCurrent >= i and 1 or 0

    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nShow)
    wndNodeProgress:SetProgress(nShow)
  end


  -- Secondary Resource (Focus)
  self:UpdateProgressBar(unitPlayer)


  -- Innate State Indicator
  self:ShowInnateIndicator()

end


--
-- MEDIC

function VikingClassResources:UpdateMedicResources(unitPlayer, nResourceMax, nResourceCurrent)

  local nPartialMax   = 3
  local unitPlayer    = GameLib.GetPlayerUnit()
  local nPartialCount = 0

  --
  -- Primary Resource
  self:UpdateProgressBar(unitPlayer)

  -- Primary / Partial Resource
  --   This is a bit tricky, a buff is used to show partial fill on the primary resource
  tBuffs = unitPlayer:GetBuffs()

  for idx, tCurrBuffData in pairs(tBuffs.arBeneficial or {}) do
    if tCurrBuffData.splEffect:GetId() == 42569 then
      nPartialCount = tCurrBuffData.nCount
      break
    end
  end

  for i = 1, nResourceMax do
    local nProgress = nPartialMax
    if i-1 < nResourceCurrent then
      nProgress = nPartialMax
    elseif i-1 == nResourceCurrent then
      nProgress = nPartialCount
    else
      nProgress = 0
    end

    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nPartialMax)
    wndNodeProgress:SetProgress(nProgress)
  end

  -- Innate State Indicator
  self:ShowInnateIndicator()

end



--
-- STALKER

function VikingClassResources:UpdateStalkerResources(unitPlayer, nResourceMax, nResourceCurrent)

  -- Primary Resource
  self:UpdateProgressBar(unitPlayer, nResourceMax, nResourceCurrent)

  -- Innate State Indicator
  self:ShowInnateIndicator()
end



--
-- SPELLSLINGER

function VikingClassResources:UpdateSpellslingerResources(unitPlayer, nResourceMax, nResourceCurrent)

  local nNodes            = 4
  local unitPlayer        = GameLib.GetPlayerUnit()
  local nNodeProgressSize = nResourceMax / nNodes


  -- Primary Resource
  self:UpdateProgressBar(unitPlayer)

  -- Innate State Indicator
  self:ShowInnateIndicator()

  for i = 1, nNodes do
    local nPartialProgress = nResourceCurrent - (nNodeProgressSize * (i - 1))
    local wndNodeProgress = self.wndMain:FindChild("Node"..i):FindChild("NodeProgress")
    wndNodeProgress:SetMax(nNodeProgressSize)
    wndNodeProgress:SetProgress(nPartialProgress, nResourceMax)
  end

end


function VikingClassResources:OnEnteredCombat()
end


function VikingClassResources:OnOutOfCombatFade()
end


-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

--
-- UpdateInnateProgress
--
-- Innates that have timers use this method to indicate their decay progress

function VikingClassResources:UpdateInnateProgress(bInnate)

  if bInnate and not self.bInnateActive then

    self.bInnateActive = true

    local wndSecondaryProgress = self.wndMain:FindChild("SecondaryProgressBar")
    local nProgressMax         = tInnateTime[self.eClassID] * 10
    wndSecondaryProgress:Show(true)
    wndSecondaryProgress:SetMax(nProgressMax)
    wndSecondaryProgress:SetProgress(nProgressMax)

    self.InnateTimerTick = ApolloTimer.Create(0.01, true, "OnInnateTimerTick", self)
    self.InnateTimerDone = ApolloTimer.Create(tInnateTime[self.eClassID], false, "OnInnateTimerDone", self)
  end
end

function VikingClassResources:OnInnateTimerTick()
  self.wndMain:FindChild("SecondaryProgressBar"):SetProgress(0, 10)
end

function VikingClassResources:OnInnateTimerDone()
  self.bInnateActive = false
  self.InnateTimerTick:Stop()
  self.wndMain:FindChild("SecondaryProgressBar"):Show(false)
end

--
-- ShowInnateIndicator
--
--   The animated sprite shown when your Innate is active

function VikingClassResources:ShowInnateIndicator()
  local bInnate = GameLib.IsCurrentInnateAbilityActive()
  self.wndMain:FindChild("InnateGlow"):Show(bInnate)
end




--
--
--
--
function VikingClassResources:HelperToggleVisibiltyPreferences(wndParent, unitPlayer)
  -- TODO: REFACTOR: Only need to update this on Combat Enter/Exit
  -- Toggle Visibility based on ui preference
  local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

  if nVisibility == 2 then --always off
    wndParent:Show(false)
  elseif nVisibility == 3 then --on in combat
    wndParent:Show(unitPlayer:IsInCombat())
  elseif nVisibility == 4 then --on out of combat
    wndParent:Show(not unitPlayer:IsInCombat())
  else
    wndParent:Show(true)
  end
end


--
--
--
--
function VikingClassResources:OnGeneratePetCommandTooltip(wndControl, wndHandler, eType, arg1, arg2)
  local xml = nil
  if eType == Tooltip.TooltipGenerateType_PetCommand then
    xml = XmlDoc.new()
    xml:AddLine(arg2)
    wndControl:SetTooltipDoc(xml)
  elseif eType == Tooltip.TooltipGenerateType_Spell then
    xml = XmlDoc.new()
    if arg1 ~= nil then
      xml:AddLine(arg1:GetFlavor())
    end
    wndControl:SetTooltipDoc(xml)
  end
end

local VikingClassResourcesInst = VikingClassResources:new()
VikingClassResourcesInst:Init()
