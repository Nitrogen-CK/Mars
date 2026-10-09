// Two Ready boxes built a metre off a yawed three-slot platter land in slots 0 and 1, in request order: each becomes a scene
// node of the platter root, rests at its slot pose (bounds centre over the slot, bounds bottom on it) in the world, and carries
// the platter and its slot.
class UMars_AutoTest_Platter_LoadFillsLowestSlotAndParentsThePiece : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -9000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _First;
    private FCk_Handle_FoodPiece _Second;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, 30.0, 0.0), k_Origin), Make_PlatterSpec(3, 0.0f));
        _First = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);
        _Second = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 50.0, 0.0)), 0.5);

        Add_Step_WaitUntil("both boxes are Ready", n"Check_Ready");
        Add_Step("load both", n"Step_Load");
        Add_Step_WaitUntil("both landed", n"Check_Landed");
        Add_Step_WaitFrames("the attach composes the world poses", 2);
        Add_Step("the slots, the parent, the poses and the memberships", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_First) && Get_HasReadied(_Second));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_Platter, _First);
        Load(_Platter, _Second);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 2 || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 2, "the platter holds two");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 0, "nothing is pending");
        Assert_Equals_Int(_Loaded.Num(), 2, "two landings were announced");
        if (_Loaded.Num() == 2)
        {
            Assert_True(_Loaded[0].Piece == _First && _Loaded[0].Slot == 0, f"the first box landed first, in slot 0 (got slot {_Loaded[0].Slot})");
            Assert_True(_Loaded[1].Piece == _Second && _Loaded[1].Slot == 1, f"the second box landed second, in slot 1 (got slot {_Loaded[1].Slot})");
        }

        Assert_Piece(_First, 0);
        Assert_Piece(_Second, 1);
    }

    private void Assert_Piece(FCk_Handle_FoodPiece InPiece, int32 InSlot)
    {
        Assert_True(Get_Parent(InPiece) == Get_Root(_Platter), f"slot {InSlot}'s piece is a scene node of the platter root");

        const auto Expected = Get_SlotWorld(_Platter, InPiece, InSlot).GetLocation();
        const auto Actual = Get_World(InPiece).GetLocation();
        Assert_True(Actual.Equals(Expected, 0.1), f"slot {InSlot}'s piece rests at its slot pose ({Actual} vs {Expected})");

        Assert_True(InPiece.TryGet_Platter() == _Platter, f"slot {InSlot}'s piece carries the platter");
        const auto Slot = InPiece.Get_PlatterSlot();
        Assert_True(Slot.IsSet() && Slot.GetValue() == InSlot, f"slot {InSlot}'s piece carries its slot");
    }
}
