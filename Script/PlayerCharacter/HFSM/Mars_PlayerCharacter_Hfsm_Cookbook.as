namespace constants_cookbook
{
    const float64 k_ClosedSpineOffset = 8.619;
    const float64 k_OpenHalfWidth = 18.156;
}

struct FMars_Cookbook_ReadingFrame
{
    float32 Alpha = 0.0f;
    FVector HandOffset;
    float32 GripBelowCentre = 16.0f;
    FMars_FPHands_RestSpec Rest;
}

namespace utils_cookbook
{
    FGameplayTag Get_PreviousIntent()
    { return GameplayTags::ResolveGameplayTag(n"Mars.Intent.Cookbook.Previous"); }

    FGameplayTag Get_NextIntent()
    { return GameplayTags::ResolveGameplayTag(n"Mars.Intent.Cookbook.Next"); }

    // Raw visual lookup also serves forced close while a mount or inventory transfer is still pending.
    UMars_CookbookPresentationComponent TryGet_PresentationBook(FCk_Handle InPresentation)
    {
        if (ck::Is_NOT_Valid(InPresentation))
        { return nullptr; }

        for (auto Node : utils_fphands::Get_TransformTree(InPresentation))
        {
            const auto Components = utils_unreal_component::Get_ComponentsByType(Node, UMars_CookbookPresentationComponent);
            if (Components.Num() == 1)
            { return Cast<UMars_CookbookPresentationComponent>(Components[0]); }
        }
        return nullptr;
    }

    // The moving cover opens around a spine at source X=0. Shift the visual toward the hand centre while its closed
    // bounds centre moves back to the spine; the two source-space terms compensate before the mount rotation.
    FMars_FPHands_Hold Make_ReadingHold(FCk_Handle_Item InItem, const FMars_Cookbook_ReadingFrame& InFrame)
    {
        auto Hold = utils_fphands::Make_Hold(InItem);
        const auto Alpha = Math::Clamp(InFrame.Alpha, 0.0f, 1.0f);
        if (Hold.Kind == EMars_FPHands_HoldKind::Empty || Alpha <= 0.0f)
        { return Hold; }

        const auto ClosedGrips = utils_fphands::Get_RestTargets(InFrame.Rest, Hold,
            FMars_FPHands_TargetFrame(FTransform::Identity, FVector::ZeroVector, FVector::ZeroVector));
        const auto ReadOffset = InFrame.HandOffset * Alpha;
        const auto BookScale = Hold.Shape.Scale.X;
        const auto OpenHalfWidth = constants_cookbook::k_OpenHalfWidth * BookScale;
        auto Grips = FMars_FPHands_SocketGrips();
        Grips.Right = FTransform(InFrame.Rest.GripRotation_R, Math::Lerp(ClosedGrips.Right.GripInHand.GetLocation(),
            InFrame.HandOffset + FVector(0.0, OpenHalfWidth + InFrame.Rest.PalmSurfaceOffset, -InFrame.GripBelowCentre), Alpha));
        Grips.Left = FTransform(InFrame.Rest.GripRotation_L, Math::Lerp(ClosedGrips.Left.GripInHand.GetLocation(),
            InFrame.HandOffset + FVector(0.0, -OpenHalfWidth - InFrame.Rest.PalmSurfaceOffset, -InFrame.GripBelowCentre), Alpha));
        Hold.SocketGrips = TOptional<FMars_FPHands_SocketGrips>(Grips);
        Hold.Faces.RightY = Math::Lerp(Hold.Faces.RightY, OpenHalfWidth, Alpha);
        Hold.Faces.LeftY = Math::Lerp(Hold.Faces.LeftY, -OpenHalfWidth, Alpha);
        Hold.Bounds.Centre.X = Math::Lerp(Hold.Bounds.Centre.X, 0.0, Alpha);
        Hold.Bounds.HalfExtents.X = Math::Lerp(Hold.Bounds.HalfExtents.X, OpenHalfWidth, Alpha);
        Hold.HeldOffset = FTransform(FRotator::ZeroRotator, FVector(constants_cookbook::k_ClosedSpineOffset * BookScale * Alpha, 0.0, 0.0)) * Hold.HeldOffset;
        Hold.HeldOffset.SetLocation(Hold.HeldOffset.GetLocation() + ReadOffset);
        Hold.Shape = FMars_FPHands_ShapeMesh();
        return Hold;
    }

    // The current assembled presentation, never a stowed or already-launched item waiting on its deferred transfer.
    UMars_CookbookPresentationComponent TryGet_HeldBook(FCk_Handle InPlayer)
    {
        if (ck::Is_NOT_Valid(InPlayer))
        { return nullptr; }

        const auto HeldItem = InPlayer.As_HeldItem(ECk_SanityCheck::UnChecked);
        const auto Use = InPlayer.As_HeldItemUse(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(HeldItem) || (ck::IsValid(Use) && Use.Get_IsCurrentItemLaunched()))
        { return nullptr; }

        const auto Item = HeldItem.Get_CurrentItem();
        auto Presentation = HeldItem.Get_PresentationEntity();
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Presentation) || Presentation.Is_WorldItem() == false
            || Presentation.As_WorldItem().Get_Mount() != EMars_WorldItem_Mount::Held)
        { return nullptr; }

        return TryGet_PresentationBook(Presentation);
    }
}

// Local free-roam controls only. CkIntent owns all key subscriptions; switching item, launching it, leaving Locomotion
// or replacing the matcher closes the book. The assembly also closes on unmount and destruction.
class UMars_SmTask_CookbookIntents : UMars_SmTask_IntentEdges
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Player;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_HeldItemUse _Use;
    private UMars_CookbookPresentationComponent _Book;
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_Item _ObservedItem;
    private bool _HoldOverrideActive = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        _Player = ck::Ctx(InHandle);
        _HeldItem = _Player.As_HeldItem();
        _Use = _Player.As_HeldItemUse();
        _Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);
        TryBind_ReadingBook();
        _HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnCookbookHeldItemChanged"));
        _Use.BindTo_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnCookbookLaunched"));
        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        DoClose_Book();
        DoUnbind_ReadingBook();
        if (ck::IsValid(_HeldItem))
        { _HeldItem.UnbindFrom_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnCookbookHeldItemChanged")); }
        if (ck::IsValid(_Use))
        { _Use.UnbindFrom_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnCookbookLaunched")); }

        _Player = FCk_Handle();
        _HeldItem = FCk_Handle_HeldItem();
        _Use = FCk_Handle_HeldItemUse();
        _Book = nullptr;
        _Hands = FCk_Handle_FPHands();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Book))
        { TryBind_ReadingBook(); }
        return ECk_SmTaskResult::Running;
    }

    protected void OnMatcherRebound() override
    { DoClose_Book(); }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        const auto Previous = InIntent == utils_cookbook::Get_PreviousIntent();
        if (Previous == false && InIntent != utils_cookbook::Get_NextIntent())
        { return; }

        TryBind_ReadingBook();
        if (ck::IsValid(_Book) && _Book.Get_IsOpen())
        { _Book.Request_Turn(Previous ? -1 : 1); }
    }

    private void DoClose_Book()
    {
        if (ck::IsValid(_Book))
        { _Book.Request_Close(); }

        // The component may have arrived after OnHeldItemChanged, or a launch may already guard normal input lookup.
        if (ck::IsValid(_HeldItem))
        {
            auto Current = utils_cookbook::TryGet_PresentationBook(_HeldItem.Get_PresentationEntity());
            if (ck::IsValid(Current) && Current != _Book)
            { Current.Request_Close(); }
        }
    }

    UFUNCTION()
    private void OnCookbookHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrevious, FCk_Handle_Item InNew)
    {
        DoClose_Book();
        DoUnbind_ReadingBook();
        TryBind_ReadingBook();
    }

    UFUNCTION()
    private void OnCookbookLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    { DoClose_Book(); }

    private void TryBind_ReadingBook()
    {
        auto Book = utils_cookbook::TryGet_HeldBook(_Player);
        if (Book == _Book)
        { return; }

        DoUnbind_ReadingBook();
        _Book = Book;
        if (ck::Is_NOT_Valid(_Book) || ck::Is_NOT_Valid(_HeldItem))
        { return; }

        _ObservedItem = _HeldItem.Get_CurrentItem();
        _Book.OnReadingPoseChanged.AddUFunction(this, n"OnReadingPoseChanged");
        OnReadingPoseChanged(_Book.Get_ReadingAlpha());
    }

    private void DoUnbind_ReadingBook()
    {
        if (ck::IsValid(_Book))
        { _Book.OnReadingPoseChanged.Unbind(this, n"OnReadingPoseChanged"); }
        DoReset_ReadingHold();
        _Book = nullptr;
        _ObservedItem = FCk_Handle_Item();
    }

    private void DoReset_ReadingHold()
    {
        if (_HoldOverrideActive && ck::IsValid(_Hands) && ck::IsValid(_HeldItem)
            && _HeldItem.Get_CurrentItem() == _ObservedItem)
        { _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_ObservedItem)); }
        _HoldOverrideActive = false;
    }

    UFUNCTION()
    private void OnReadingPoseChanged(float32 InAlpha)
    {
        if (ck::Is_NOT_Valid(_Book) || ck::Is_NOT_Valid(_Hands) || ck::Is_NOT_Valid(_HeldItem) || ck::Is_NOT_Valid(_ObservedItem)
            || _HeldItem.Get_CurrentItem() != _ObservedItem)
        { return; }

        if (InAlpha <= 0.0f)
        {
            DoReset_ReadingHold();
            return;
        }

        if (ck::IsValid(_Use) && _Use.Get_IsCurrentItemLaunched())
        { return; }

        auto Frame = FMars_Cookbook_ReadingFrame();
        Frame.Alpha = InAlpha;
        Frame.HandOffset = _Book.ReadingHandOffset;
        Frame.GripBelowCentre = _Book.ReadingGripBelowCentre;
        Frame.Rest = _Hands.Get_Spec().Rest;
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_ObservedItem, utils_cookbook::Make_ReadingHold(_ObservedItem, Frame)));
        _HoldOverrideActive = true;
    }
}
