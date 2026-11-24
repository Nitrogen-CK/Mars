// The break and the detach both part processors run. They write the part's state and its pending sever, so they live on
// the processors and nowhere else.
//
// A detach disables the zone and releases its hurtboxes before it requests the detach, so the hurtbox nodes are gone before
// the leg's parts are released. The leg stays the body's and keeps carrying the part, so its state stays readable until
// the body dies. A sever releases the leg's parts and destroys them on every machine: what falls is one limb the part's
// host spawns, once, with authority, from OnSevered.
UCLASS(Abstract)
class UMars_Processor_BodyPart_Base : UCk_Processor_Script_Base_UE
{
    // Disables the zone, marks the part Broken and raises OnBroken.
    protected void DoBreak(FCk_Handle_BodyPart& InPart, const FMars_DamageEvent& InCause)
    {
        auto Zone = InPart.Get_Zone();
        Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));

        InPart.Get_Fragment(FMars_Fragment_BodyPart).State = EMars_BodyPart_State::Broken;

        if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
        { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnBroken.Broadcast(InPart, InCause); }
    }

    // Disables the zone, releases its hurtboxes, marks the part Severed and asks the leg to detach; OnSevered fires from
    // OnLegDetached with what the detach released.
    protected void DoDetach(FCk_Handle_BodyPart& InPart, const FMars_DamageEvent& InCause)
    {
        auto Zone = InPart.Get_Zone();
        Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));
        Zone.Request_ReleaseHurtboxes(FMars_Request_HitZone_ReleaseHurtboxes());

        InPart.Get_Fragment(FMars_Fragment_BodyPart).State = EMars_BodyPart_State::Severed;

        // Only the sever detaches a leg, and a part severs once (it left Attached above), so a leg already detached is a
        // defect. No detach would fire: the sever completes here with nothing released.
        auto Leg = InPart.Get_Leg();
        if (ck::EnsureIfNot(utils_procedural_leg::Get_IsAttached(Leg), f"[BodyPart] [{InPart.ToString()}] severed a leg that was no longer attached: only the sever detaches a leg"))
        {
            if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
            { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnSevered.Broadcast(InPart, InCause, TArray<FCk_Handle_Transform>()); }

            return;
        }

        InPart.AddOrGet_Fragment(FMars_Fragment_BodyPart_PendingSever).Cause = InCause;

        utils_procedural_leg::BindTo_OnDetached(Leg, FCk_Delegate_ProceduralLeg_OnDetached(this, n"OnLegDetached"),
            ECk_Signal_BindingPolicy::FireIfPayloadInFlightThisFrame, ECk_Signal_PostFireBehavior::Unbind);

        utils_procedural_leg::Request_Detach(Leg, FCk_Request_ProceduralLeg_Detach(ECk_ProceduralLeg_ReleasedPartsOwnership::KeepBodyOwned));
    }

    // Bound only by DoDetach, on a part's own leg, after it stashed the cause in PendingSever. Runs inside the leg's detach
    // drain, while the rig is still bound: OnSevered's handlers read the released parts, which are destroyed right after.
    UFUNCTION()
    private void OnLegDetached(FCk_Handle_ProceduralLeg InLeg, FCk_ProceduralLeg_ReleasedParts InReleasedParts)
    {
        auto Part = InLeg.As_BodyPart();
        const TArray<FCk_Handle_Transform> Released = InReleasedParts.Get_Parts();

        auto Cause = FMars_DamageEvent();
        if (ck::EnsureIfNot(Part.Has_Fragment(FMars_Fragment_BodyPart_PendingSever), f"[BodyPart] [{Part.ToString()}] detached with no pending sever cause") == false)
        {
            Cause = Part.Get_Fragment(FMars_Fragment_BodyPart_PendingSever).Cause;
            Part.Request_TryRemove(FMars_Fragment_BodyPart_PendingSever);
        }

        if (Part.Has_Fragment(FMars_Fragment_BodyPart_Signals))
        { Part.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnSevered.Broadcast(Part, Cause, Released); }

        for (auto ReleasedPart : Released)
        {
            FCk_Handle Entity = ReleasedPart;
            utils_entity_lifetime::Request_DestroyEntity(Entity);
        }
    }
}
