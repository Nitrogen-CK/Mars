// The Dial tests' rig: a dial on its own entity with its index changes recorded.
UCLASS(Abstract)
class UMars_AutoTestRig_Dial : UCk_AutoTest_Base
{
    protected FCk_Handle_Dial _Dial;
    protected TArray<int32> _Changes;

    protected FCk_Handle_Dial AddDial(FCk_Handle InHandle, FMars_Dial_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Dial = utils_dial::Add(Entity, InSpec);
        if (ck::IsValid(_Dial))
        { _Dial.BindTo_OnIndexChanged(FMars_Delegate_Dial_OnIndexChanged(this, n"OnRigIndexChanged")); }

        return _Dial;
    }

    protected FMars_Dial_Spec Make_Spec(int32 InPositions, int32 InStartIndex) const
    {
        auto Spec = FMars_Dial_Spec();
        Spec.Positions = InPositions;
        Spec.StartIndex = InStartIndex;
        return Spec;
    }

    // True once the dial has drained its requests.
    protected bool Get_IsDrained() const
    {
        return _Dial.Has_Fragment(FMars_Fragment_Dial_Requests) == false;
    }

    UFUNCTION()
    private void OnRigIndexChanged(FCk_Handle_Dial InDial, int32 InIndex)
    {
        _Changes.Add(InIndex);
    }
}
