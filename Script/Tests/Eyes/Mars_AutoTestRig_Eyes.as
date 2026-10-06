// The Eyes tests' rig: a face node of its own in the test's isolated Z band, the eyes composed on it, the presentation
// check every eyes test opens with, and the layer clears.
UCLASS(Abstract)
class UMars_AutoTestRig_Eyes : UCk_AutoTest_Base
{
    protected FCk_Handle_Eyes _Eyes;

    // A transform root of its own at InLocation.
    protected FCk_Handle_Transform Make_FaceNode(FCk_Handle InHandle, FVector InLocation)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
    }

    // Fails the test, and returns false, when the eyes have no presentation in this world.
    protected bool Assert_HasPresentation()
    {
        Assert_Valid(_Eyes, "Add with a valid spec returns a valid handle");
        if (_Eyes.Get_HasPresentation() == false)
        {
            FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false");
            return false;
        }

        return true;
    }

    // What a test asserts in Step_AssertPresentation once the eyes are known to be presented.
    protected void Assert_AfterPresentation()
    {
    }

    UFUNCTION()
    protected void Step_AssertPresentation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (Assert_HasPresentation())
        { Assert_AfterPresentation(); }
    }

    UFUNCTION()
    protected void Step_ClearEmote(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::Emote));
    }

    UFUNCTION()
    protected void Step_ClearState(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::State));
    }

    UFUNCTION()
    protected void Check_EmotePlaying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote());
    }
}
