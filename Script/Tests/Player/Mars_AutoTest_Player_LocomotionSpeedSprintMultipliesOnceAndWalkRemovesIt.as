// The movement speed attribute (utils_locomotion_speed) starts at the Spec's Walk speed; Sprint adds the sprint modifier
// once (applied twice it still reads the Sprint speed, not Sprint x Sprint / Walk), and Walk removes it again. No actor:
// the multiplier comes from the Spec retained at Add.
class UMars_AutoTest_Player_LocomotionSpeedSprintMultipliesOnceAndWalkRemovesIt : UCk_AutoTest_Base
{
    private const float32 k_Walk = 400.0f;
    private const float32 k_Sprint = 600.0f;

    private FCk_Handle _Player;
    private FCk_Handle_FloatAttribute _Speed;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;
        _Speed = utils_locomotion_speed::Add(_Player, FMars_LocomotionSpeed_Spec(k_Walk, k_Sprint));

        Add_Step("the attribute starts at the walk speed; sprint, twice", n"Step_SprintTwice");
        Add_Step_WaitUntil("the speed reaches the sprint speed", n"Check_AtSprint", 0, 0);
        Add_Step("one modifier: the speed is the sprint speed, not past it; walk", n"Step_AssertSprintAndWalk");
        Add_Step_WaitUntil("the speed is back at the walk speed", n"Check_AtWalk", 0, 0);
        Add_Step("the modifier is gone", n"Step_AssertWalk");
        Run_Steps(InHandle);
    }

    private float64 Get_Speed() const
    {
        return _Speed.Get_FinalValue(ECk_MinMaxCurrent::Current);
    }

    UFUNCTION()
    private void Step_SprintTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Speed, "utils_locomotion_speed::Add composed the attribute");
        Assert_Equals_Float(Get_Speed(), k_Walk, 0.01, "the attribute starts at the walk speed");
        Assert_False(utils_locomotion_speed::Get_IsSprinting(_Player), "no sprint modifier before the first sprint");
        utils_locomotion_speed::Apply(_Player, EMars_LocomotionSpeed::Sprint);
        utils_locomotion_speed::Apply(_Player, EMars_LocomotionSpeed::Sprint);
    }

    UFUNCTION()
    private void Check_AtSprint(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Speed() > k_Walk + 1.0);
    }

    UFUNCTION()
    private void Step_AssertSprintAndWalk(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_Speed(), k_Sprint, 0.01, "one sprint modifier: the speed is Sprint (a second would read Sprint x 1.5)");
        Assert_True(utils_locomotion_speed::Get_IsSprinting(_Player), "the sprint modifier is on");
        utils_locomotion_speed::Apply(_Player, EMars_LocomotionSpeed::Walk);
    }

    UFUNCTION()
    private void Check_AtWalk(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(Get_Speed() - k_Walk) < 0.01);
    }

    UFUNCTION()
    private void Step_AssertWalk(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_locomotion_speed::Get_IsSprinting(_Player), "Walk removed the sprint modifier");
    }
}
