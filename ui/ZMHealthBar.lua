CoD.HealthBar = InheritFrom(LUI.UIElement)

require("UI.Utils")

function CoD.HealthBar.new(HudRef, InstanceRef)

	local Widget = LUI.UIElement.new()

	if PreLoadFunc then
		PreLoadFunc(Widget, InstanceRef)
	end

	Widget:setUseStencil(false)
	Widget:setClass(CoD.HealthBar)
	Widget.id = "healthBar"
	Widget.soundSet = "HUD"
	Widget.anyChildUsesUpdateState = true
	Widget:setLeftRight(true, false, 0, 155)
	Widget:setTopBottom(false, true, 0, -131)
	Widget:setYRot(30.000000)

	Widget.healthBackBar = LUI.UIImage.new()
	Widget.healthBackBar:setLeftRight(false, false, 0, 94)
	Widget.healthBackBar:setTopBottom(false, true, 0, -7)
	Widget.healthBackBar:setImage(GetCachedImage("health_bar_black"))
	Widget.healthBackBar:setMaterial(LUI.UIImage.GetCachedMaterial("uie_feather_blend"))
	Widget.healthBackBar:setAlpha(0.2)

	Widget:addElement(Widget.healthBackBar)

	Widget.healthBar = LUI.UIImage.new()
	Widget.healthBar:setLeftRight(false, false, 0, 94)
	Widget.healthBar:setTopBottom(false, true, 0, -7)
	Widget.healthBar:setImage(GetCachedImage("health_bar_gradient"))
	Widget.healthBar:setMaterial(LUI.UIImage.GetCachedMaterial("uie_wipe"))
	Widget.healthBar:setShaderVector(1, 0.01, 0, 0, 0)
	Widget.healthBar:setShaderVector(2, 1, 0, 0, 0)
	Widget.healthBar:setShaderVector(3, 0, 0, 0, 0)
	Widget:addElement(Widget.healthBar)

	Widget.healthBar:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "player_healthbar"), function(ModelRef)
		local modelValue = Engine.GetModelValue(ModelRef)
		
		if modelValue then
			local shaderW = CoD.GetVectorComponentFromString(modelValue, 1)
			local shaderX = CoD.GetVectorComponentFromString(modelValue, 2)
			local shaderY = CoD.GetVectorComponentFromString(modelValue, 3)
			local shaderZ = CoD.GetVectorComponentFromString(modelValue, 4)

			Widget.healthBar:beginAnimation("keyframe", 75, false, false, CoD.TweenType.Linear)

			Widget.healthBar:setRGB(1, modelValue, modelValue) -- modelValue is always below 1 as it's (health/maxhealth) to save bits
			Widget.healthBar:setShaderVector(0, shaderW, shaderX, shaderY, shaderZ)

			Widget.healthBar:registerEventHandler("transition_complete_keyframe", function(Sender, Event)
				if Event.interrupted then
					Widget.clipFinished(Sender, Event)
				else
					Sender:registerEventHandler("transition_complete_keyframe", Widget.clipFinished)
				end
			end)

		end
	end)

	local HiddenAnim = function (Sender, Event)
		if not Event.interrupted then
			Sender:beginAnimation("keyframe", 150, false, false, CoD.TweenType.Linear)
		end
		Sender:setAlpha(0)
		if Event.interrupted then
			Widget.clipFinished(Sender, Event)
		else
			Sender:registerEventHandler("transition_complete_keyframe", Widget.clipFinished)
		end
	end

	Widget.clipsPerState = {
		DefaultState = {
			DefaultClip = function()
				Widget:setupElementClipCounter(2)

				Widget.healthBar:completeAnimation()
				Widget.healthBar:setAlpha(1)
				Widget.clipFinished(Widget.healthBar, {})

				Widget.healthBackBar:completeAnimation()
				Widget.healthBackBar:setAlpha(0.2)
				Widget.clipFinished(Widget.healthBackBar, {})
			end,
			Hidden = function ()
				Widget:setupElementClipCounter(2)

				Widget.healthBar:completeAnimation()
				Widget.healthBar:setAlpha(1)
				HiddenAnim(Widget.healthBar, {0})

				Widget.healthBackBar:completeAnimation()
				Widget.healthBackBar:setAlpha(0.2)
				HiddenAnim(Widget.healthBackBar, {0})
			end
		},
		Hidden = {
			DefaultClip = function()
				Widget:setupElementClipCounter(2)

				Widget.healthBar:completeAnimation()
				Widget.healthBar:setAlpha(0)
				Widget.clipFinished(Widget.healthBar, {})

				Widget.healthBackBar:completeAnimation()
				Widget.healthBackBar:setAlpha(0)
				Widget.clipFinished(Widget.healthBackBar, {})
			end,
			DefaultState = function ()
				Widget:setupElementClipCounter(2)

				Widget.healthBar:completeAnimation()
				Widget.healthBar:setAlpha(0)
				HiddenAnim(Widget.healthBar, {1})

				Widget.healthBackBar:completeAnimation()
				Widget.healthBackBar:setAlpha(0)
				HiddenAnim(Widget.healthBackBar, {0.2})
			end
		}
	}

	Widget.StateTable = {
		{
			stateName = "Hidden",
			condition = function(HudRef, ItemRef, UpdateTable)
				return ShouldHideWidget(InstanceRef)
			end
		}
	}

	Widget:mergeStateConditions(Widget.StateTable)

	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "hudItems.playerSpawned")
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_HUD_VISIBLE)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_HUD_HARDCORE)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_GAME_ENDED)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_DEMO_CAMERA_MODE_MOVIECAM)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_DEMO_ALL_GAME_HUD_HIDDEN)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_IN_KILLCAM)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_IS_FLASH_BANGED)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_IS_SCOPED)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_IN_VEHICLE)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_IN_GUIDED_MISSILE)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_UI_ACTIVE)
	SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, "UIVisibilityBit." .. Enum.UIVisibilityBit.BIT_IN_REMOTE_KILLSTREAK_STATIC)

	LUI.OverrideFunction_CallOriginalSecond(Widget, "close", function(SenderObj)
		SenderObj.healthBackBar:close()
		SenderObj.healthBar:close()
	end)

	if PostLoadFunc then
		PostLoadFunc(Widget, InstanceRef, HudRef)
	end

	return Widget
end
