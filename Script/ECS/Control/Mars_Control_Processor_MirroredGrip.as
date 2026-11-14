// Another machine's grip, shown here: while the grip ledger says Gripped and this machine does not hold the grip, the
// shown alpha follows the ledger's Pull through the control's own spring (Step_Spring) and scrubs this machine's Mover
// when it has one; a control without a Mover (a pull its assembly draws, which reads TryGet_ShownGripAlpha) is mirrored
// all the same. The grip mirror (UMars_Processor_Control_GripMirror) starts it from where a grip starts and stops it; the
// engage mirror stops it when the engage's MoveTo takes the handle. Presentation only: nothing simulated reads the
// mirrored alpha. While this machine has a grip of its own on the control (one begun before a refusal came back), that
// grip owns the Mover and the mirrored slot only keeps its alpha.
class UMars_Processor_Control_MirroredGrip : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Control_GripMirror");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
        Query.Require(FMars_Tag_Control_MirroringGrip);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Control = InHandle.As_Control();
        auto& Local = Control.Get_Fragment(FMars_Fragment_Control_Local);
        auto Mover = Local.Mover;

        // Stopped this frame (the slot is cleared at once, the tag at the end of the frame): a scrub now would stop the
        // engage's MoveTo.
        if (Local.MirroredGrip.IsSet() == false)
        { return; }

        if (Local.Manipulation.IsSet())
        {
            Local.MirroredGrip = FMars_Control_Spring(Local.Manipulation.GetValue().Alpha, 0.0f);
            return;
        }

        const auto Pull = Control.Get_Fragment(FMars_Fragment_Control_Grip).Pull;
        auto Spring = Local.MirroredGrip.GetValue();
        Control.Get_Fragment(FMars_Fragment_Control_Params).Manipulation.Step_Spring(Spring, Pull, float32(InDeltaT.Get_Seconds()));
        Local.MirroredGrip = Spring;

        if (ck::IsValid(Mover))
        { Mover.Request_Scrub(FMars_Request_Mover_Scrub(Spring.Alpha)); }
    }
}
