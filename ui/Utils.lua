EnableGlobals()

function SubscribeToModelAndUpdateState(InstanceRef, HudRef, Widget, Model)
	Widget:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), Model), function(ModelRef)
		HudRef:updateElementState(Widget, 
			{
				name = "model_validation", 
				menu = HudRef, 
				modelValue = Engine.GetModelValue(ModelRef), 
				modelName = Model
			}
		)
	end)
end

function ShouldHideWidget(InstanceRef)
	local shouldHide = IsModelValueTrue(InstanceRef, "hudItems.playerSpawned")

	if shouldHide then
		if Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_HUD_VISIBLE) 
		and Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_WEAPON_HUD_VISIBLE) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_HUD_HARDCORE) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_GAME_ENDED) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_DEMO_CAMERA_MODE_MOVIECAM) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_DEMO_ALL_GAME_HUD_HIDDEN) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_IN_KILLCAM) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_IS_FLASH_BANGED) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_IS_SCOPED) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_IN_VEHICLE) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_IN_GUIDED_MISSILE) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN) 
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_UI_ACTIVE)
		and not Engine.IsVisibilityBitSet(InstanceRef, Enum.UIVisibilityBit.BIT_IN_REMOTE_KILLSTREAK_STATIC) then
			shouldHide = false
		else
			shouldHide = true
		end
	end

	return shouldHide
	
end

-- This function here is so I don't register images more than once if they're already cached, this is to prevent possibly weird issues that I know of
-- but can't confirm due to not enough testing.

-- Issues being: 
-- Too many registrations causes FX to disappear early (string limit?)
Ray = {}
function CacheImage(image)
	if not Ray.CachedImages then
		Ray.CachedImages = {}
	end

	if not Ray.CachedImages[image] then
		Ray.CachedImages[image] = RegisterImage(image)
	end

end

function GetCachedImage(image)
	CacheImage(image)

	return Ray.CachedImages[image]
end

DisableGlobals()