// Preconfigured locks, doors and keys for the sandbox's key room (room 6, Mars.Sandbox.BuildRoom6 in
// Script/Editor/Mars_SandboxMapBuilder.as). Each lock asserts Mechanism.Channel.Keys.<Colour>; each door's sink names the rule.
// Not under Script/Editor: the saved map references them at runtime.

//--------------------------------------------------------------------------------------------------------------------------
// Locks
//--------------------------------------------------------------------------------------------------------------------------

class UMars_Sandbox_KeyLock_Red_EntityScript : UMars_KeyLock_EntityScript
{
    default _ShowInPlaceActors = false;
    default AcceptedKey = GameplayTags::Key_Mars_Red;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Keys_Red;
}

class UMars_Sandbox_KeyLock_Blue_EntityScript : UMars_KeyLock_EntityScript
{
    default _ShowInPlaceActors = false;
    default AcceptedKey = GameplayTags::Key_Mars_Blue;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Keys_Blue;
}

class UMars_Sandbox_KeyLock_Yellow_EntityScript : UMars_KeyLock_EntityScript
{
    default _ShowInPlaceActors = false;
    default AcceptedKey = GameplayTags::Key_Mars_Yellow;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Keys_Yellow;
}

class UMars_Sandbox_KeyLock_Green_EntityScript : UMars_KeyLock_EntityScript
{
    default _ShowInPlaceActors = false;
    default AcceptedKey = GameplayTags::Key_Mars_Green;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Keys_Green;
}

// Removable: the purple door is open only while a purple key is in one of its two locks.
class UMars_Sandbox_KeyLock_Purple_EntityScript : UMars_KeyLock_EntityScript
{
    default _ShowInPlaceActors = false;
    default AcceptedKey = GameplayTags::Key_Mars_Purple;
    default Release = EMars_KeyLock_Release::Removable;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Keys_Purple;
}

//--------------------------------------------------------------------------------------------------------------------------
// Doors
//--------------------------------------------------------------------------------------------------------------------------

// One red key; stays open.
class UMars_Sandbox_KeyDoor_Red_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Leaf = EMars_Gate_Leaf::Bars;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Keys_Red);
    default Sink.Latch = true;
}

// A blue key AND a yellow key, in the locks either side of it; stays open.
class UMars_Sandbox_KeyDoor_BlueYellow_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Keys_Blue);
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Keys_Yellow);
    default Sink.Rule = EMars_MechanismSink_Rule::AllChannels;
    default Sink.Latch = true;
}

// Both green locks hold a green key; stays open.
class UMars_Sandbox_KeyDoor_Green_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Leaf = EMars_Gate_Leaf::Bars;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Keys_Green);
    default Sink.Rule = EMars_MechanismSink_Rule::AllSources;
    default Sink.Latch = true;
}

// Open while either purple lock holds the key; never closes on whoever stands in it.
class UMars_Sandbox_KeyDoor_Purple_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Leaf = EMars_Gate_Leaf::Bars;
    default WaitsForClearThreshold = true;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Keys_Purple);
    default Sink.Rule = EMars_MechanismSink_Rule::AnyChannel;
}

//--------------------------------------------------------------------------------------------------------------------------
// Keys
//--------------------------------------------------------------------------------------------------------------------------

class UMars_WorldItem_Key_Red_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Key_Red();
}

class UMars_WorldItem_Key_Blue_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Key_Blue();
}

class UMars_WorldItem_Key_Green_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Key_Green();
}

class UMars_WorldItem_Key_Yellow_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Key_Yellow();
}

class UMars_WorldItem_Key_Purple_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Key_Purple();
}
