// World-mode item presets for placement (Mars.Sandbox.PlaceItems in Script/Editor/Mars_SandboxMapBuilder.as, or Place
// Actors). Not under Script/Editor: the saved map references them at runtime.

class UMars_WorldItem_Rock_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Rock();
}

class UMars_WorldItem_Ration_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Ration();
}

class UMars_WorldItem_Cog_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Cog();
}

// The backpack preset composes the cargo slots too (Mars.Sandbox.PlaceBackpack).
class UMars_WorldItem_Backpack_EntityScript : UMars_Backpack_EntityScript
{
    default Definition = mars_items::Backpack();
}
