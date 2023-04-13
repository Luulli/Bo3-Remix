-- This file will allow you to inject your own custom HUD Widgets into stock HUD without rebuilding them. Have fun!

require("UI.ZMHealthBar")

CoD.HUDInject = InheritFrom(LUI.UIElement)
CoD.HUDInject.Maps = {}

local function zmAllInjectElements(InjectionWidget, HudRef, InstanceRef)
    InjectionWidget.HealthBar = CoD.HealthBar.new(HudRef, InstanceRef)
    InjectionWidget:addElement(InjectionWidget.HealthBar)
end

local function zmAllCleanupElements(InjectionWidget)
    InjectionWidget.HealthBar:close()
end

-- Takes args to simplify adding new map entries. Use "zm_all" for mapName to incject to all maps.
-- Be warned, if you try to reference an element that does not have that element, you will get a UI Error
local function AddElementsForMap(mapName, removeElements, injectElements, cleanupElements)
    local mapTable = {
        mapName = mapName,
        removeElements = removeElements,
        injectElements = injectElements,
        cleanupElements = cleanupElements
    }

    table.insert(CoD.HUDInject.Maps, mapTable)
end

-- Constructs the table used to add/remove/cleanup elements on HUD.
local function CreateMapsTable()
    -- Add entries for new maps like this.
    -- Use nil for injection, removal, or cleanup if you don't want to use them.
    AddElementsForMap("zm_all", nil, zmAllInjectElements, zmAllCleanupElements)
end

-- Injection widget. This will be injected into the map specific HUD.
function CoD.HUDInject.new(HudRef, InstanceRef)
    local Widget = LUI.UIElement.new()
    Widget:setClass(CoD.HUDInject)
    Widget.id = "HUDInject"
    Widget.soundSet = "default"
    Widget.anyChildUsesUpdateState = false
    
    -- Injector widget takes up entire screen. This is so we can inject elements anywhere on the HUD.
    Widget:setLeftRight(true, true, 0, 0)
    Widget:setTopBottom(true, true, 0, 0)

    CreateMapsTable()

    -- Add widgets to be injected here.
    local mapName = Engine.GetCurrentMap()
    for index=1, #CoD.HUDInject.Maps do
        local mapTable = CoD.HUDInject.Maps[index]
        if mapTable.mapName == mapName or mapTable.mapName == "zm_all" then
            -- Remove elements from the map's hud
            if mapTable.removeElements then
                mapTable.removeElements(Widget, HudRef, InstanceRef)
            end
            -- Add elements to the map's hud
            if mapTable.injectElements then
                mapTable.injectElements(Widget, HudRef, InstanceRef)
            end
            -- Setup close function to cleanup
            if mapTable.cleanupElements then
                LUI.OverrideFunction_CallOriginalSecond(HudRef.T7HudMenuGameMode, "close", mapTable.cleanupElements)
            end
        end
    end

    return Widget
end

-- Original function rebuilt from disassembled file. Loading this in CSC or require() in lua will override the stock function with our custom one.
local function AddHUDWidgetsOriginal(HudRef, Unknown)
    if Engine.IsDemoPlaying() then
        if HudRef.safeArea then
            -- Demo element doesn't exist (== nil)
            if not HudRef.safeArea.Demo then
                HudRef.safeArea.Demo = CoD.Demo.new(HudRef.safeArea, InstanceRef.controller)
                HudRef.safeArea.Demo:setLeftRight(true, true, 0, 0)
                HudRef.safeArea.Demo:setTopBottom(true, true, 0, 0)
                -- Basically addElement
                HudRef:addForceClosedSafeAreaChild(HudRef.safeArea.Demo)

                HudRef.safeArea.Demo:processEvent({
                    name = "gain_focus",
                    controller = InstanceRef.controller
                })
                HudRef.safeArea.Demo:gainFocus({
                    controller = InstanceRef.controller
                })

                LUI.OverrideFunction_CallOriginalSecond(HudRef.safeArea.Demo, "close", function(Widget)
                    CoD.Menu.UnsubscribeFromControllerSubscriptionsForElement(HudRef.safeArea, Widget)
                end)

                UpdateState(HudRef.safeArea.Demo)
                HudRef:registerEventHandler("occlusion_change", function(Sender, Event)
                    if not Event.occluded then
                        Sender.safeArea.Demo:processEvent({
                            name = "gain_focus",
                            controller = InstanceRef.controller
                        })
                    end

                    CoD.Menu.OcclusionChange(Sender, Event)
                end)
            end

            -- The element exists at this point
            CoD.DemoUtility.AddInformationScreen(HudRef)

            if InstanceRef.activateDemoStartScreen then
                if not CoD.DemoUtility.LastActivatedInformationScreen == Enum.demoInformationScreenTypes.DEMO_INFORMATION_SCREEN_FILM_START_SCREEN_FADE_OUT then
                    CoD.DemoUtility.ActivateInformationScreen(HudRef, {
                        controller = InstanceRef.controller,
                        informationScreenType = Enum.demoInformationScreenTypes.DEMO_INFORMATION_SCREEN_FILM_START_SCREEN_FADE_IN,
                        animationTime = 0,
                        animationState = "fade_in"
                    })
                else
                    if InstanceRef.openHighlightStartScreen then
                        CoD.DemoUtility.OpenStartHighlightReel(HudRef, InstanceRef)
                    else
                        -- Still need to check if it exists. Just in case.
                        if HudRef.safeArea then
                            if HudRef.safeArea.Demo then
                                HudRef.safeArea.Demo:close()
                                HudRef.safeArea.Demo = nil
                            end
                        end
                    end
                end
            end
        end
    end
end

-- This function gets called when the HUD initialized. This will be used as an injection point
-- HudRef is the HUD that was opened. This is not t7hud_zm_MAPNAME. This is the parent menu file, one level up from map hud.
-- To access the MAP HUD, simply use HudRef.T7HudMenuGameMode
-- Powerup HUD can also be accessed this way: HudRef.powerupsArea
CoD.DemoUtility.AddHUDWidgets = function(HudRef, InstanceRef)
    AddHUDWidgetsOriginal(HudRef, InstanceRef)

    HudRef.T7HudMenuGameMode.HUDInject = CoD.HUDInject.new(HudRef, InstanceRef)
    HudRef.T7HudMenuGameMode:addElement(HudRef.T7HudMenuGameMode.HUDInject)
end