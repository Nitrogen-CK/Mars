// Polled conditions on the context entity's Station, shared by every station's control SM (the Searing, Fry, Batter,
// Tumbler, Cutting and Mortar *Station_Hfsm.as files beside this one).

// Polled on the context entity's Station; false without one.
class UMars_SmCondition_StationIsOperated : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Station = ck::Ctx(InHandle).As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Station))
        { return false; }

        return Station.Get_IsOperated();
    }
}

class UMars_SmCondition_StationIsNotOperated : UMars_SmCondition_StationIsOperated
{
    default _NegateResult = true;
}
