event void FMars_CookbookReadingPoseChanged(float32 InAlpha);

enum EMars_CookbookState
{
    Closed,
    Opening,
    Open,
    TurningForward,
    TurningReverse,
    Closing
}

// Local reading presentation. WorldItem owns mounting, pickup and the Jolt body.
class UMars_CookbookPresentationComponent : USkeletalMeshComponent
{
    default AnimationMode = EAnimationMode::AnimationSingleNode;
    default CollisionEnabled = ECollisionEnabled::NoCollision;
    default CastShadow = false;
    // Reuse the skeletal component's native speed tuner for this explicitly driven animation clock.
    default GlobalAnimRateScale = 1.5f;

    FMars_CookbookReadingPoseChanged OnReadingPoseChanged;

    // Camera-facing hand space: bring the open spread closer and above the closed carry position.
    UPROPERTY(EditDefaultsOnly, Category = "Cookbook")
    FVector ReadingHandOffset = FVector(-25.0, 0.0, 18.0);

    UPROPERTY(EditDefaultsOnly, Category = "Cookbook")
    float32 ReadingGripBelowCentre = 16.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Cookbook")
    TSoftObjectPtr<USkeletalMesh> BookMesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath(
        "/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Meshes/SK_Cookbook_Field.SK_Cookbook_Field"));

    UPROPERTY(EditDefaultsOnly, Category = "Cookbook")
    TArray<TSoftClassPtr<UCk_UserWidget_UE>> LeftPages;
    default LeftPages.Add(TSoftClassPtr<UCk_UserWidget_UE>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/Cookbook_Index_Left_WBP.Cookbook_Index_Left_WBP_C")));
    default LeftPages.Add(TSoftClassPtr<UCk_UserWidget_UE>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/Cookbook_Sample_Left_WBP.Cookbook_Sample_Left_WBP_C")));
    default LeftPages.Add(TSoftClassPtr<UCk_UserWidget_UE>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/Cookbook_Notes_Left_WBP.Cookbook_Notes_Left_WBP_C")));

    UPROPERTY(EditDefaultsOnly, Category = "Cookbook")
    TArray<TSoftClassPtr<UCk_UserWidget_UE>> RightPages;
    default RightPages.Add(TSoftClassPtr<UCk_UserWidget_UE>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/Cookbook_Index_Right_WBP.Cookbook_Index_Right_WBP_C")));
    default RightPages.Add(TSoftClassPtr<UCk_UserWidget_UE>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/Cookbook_Sample_Right_WBP.Cookbook_Sample_Right_WBP_C")));
    default RightPages.Add(TSoftClassPtr<UCk_UserWidget_UE>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/Cookbook_Notes_Right_WBP.Cookbook_Notes_Right_WBP_C")));

    UPROPERTY(BlueprintReadOnly, Category = "Cookbook")
    private EMars_CookbookState _State = EMars_CookbookState::Closed;
    UPROPERTY(BlueprintReadOnly, Category = "Cookbook")
    private int32 _PageSectionIndex = 0;
    private bool _Initialized = false;
    private bool _CloseAfterTurn = false;
    private float32 _Time = 0.0f;
    private float32 _PublishedReadingAlpha = 0.0f;
    private UAnimSequence _Clip;
    private TArray<UAnimSequence> _Clips;
    private TArray<UCk_UserWidget_UE> _PageWidgets;
    private TArray<UTexture2D> _PageTextures;
    private TArray<UMaterialInterface> _PageBaseMaterials;
    private TArray<UMaterialInstanceDynamic> _PageMaterials;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    { DoInitialize_Book(); }

    UFUNCTION(BlueprintOverride)
    void EndPlay(EEndPlayReason InReason)
    {
        Request_Close();
        DoRelease_Pages();
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float InDeltaSeconds)
    {
        // Ck invokes this after scene transforms settle. Synchronize the native spatial consumer even when a
        // stationary carrier's child-offset update did not reach the ordinary dirty-transform push.
        auto ComponentHandle = utils_unreal_component::TryGet_OwningHandle_FromComponent(this);
        if (utils_unreal_component::Get_CanEnableTransformPush(ComponentHandle))
        { utils_unreal_component::Request_EnableTransformPush(ComponentHandle); }
        Request_AdvancePresentation(InDeltaSeconds);
    }

    void Request_AdvancePresentation(float InDeltaSeconds)
    {
        if (_Initialized == false)
        { DoInitialize_Book(); }
        if (Get_IsOpen() && _PageTextures.IsEmpty())
        { DoPrepare_Pages(); }
        if (Get_IsTransitioning() == false || ck::Is_NOT_Valid(_Clip))
        { return; }
        _Time = Math::Min(float32(_Time + Math::Max(0.0, InDeltaSeconds) * GlobalAnimRateScale), _Clip.GetPlayLength());
        SetPosition(_Time, false);
        DoPublish_ReadingPose();
        if (_Time < _Clip.GetPlayLength())
        { return; }

        if (_State == EMars_CookbookState::Closing)
        { DoSet_Pose(EMars_CookbookState::Closed, 0); }
        else
        {
            const auto WasTurning = _State == EMars_CookbookState::TurningForward || _State == EMars_CookbookState::TurningReverse;
            if (_State == EMars_CookbookState::TurningForward)
            { ++_PageSectionIndex; }
            else if (_State == EMars_CookbookState::TurningReverse)
            { --_PageSectionIndex; }
            // The forward leaf ends on the left; the idle clip has it on the right. Keep the actual terminal pose
            // instead of snapping the leaf through 180 degrees when the turn commits.
            if (WasTurning)
            { _State = EMars_CookbookState::Open; }
            else
            { DoSet_Pose(EMars_CookbookState::Open, 1); }
            DoApply_Pages();
            if (_CloseAfterTurn)
            {
                _CloseAfterTurn = false;
                DoSet_Pose(EMars_CookbookState::Closing, 3);
            }
        }
    }

    UFUNCTION()
    void Request_Toggle()
    {
        DoInitialize_Book();
        if (_State == EMars_CookbookState::Closed)
        {
            DoPrepare_Pages();
            DoApply_Pages();
            DoSet_Pose(EMars_CookbookState::Opening, 2);
        }
        else if (_State == EMars_CookbookState::Open)
        { DoSet_Pose(EMars_CookbookState::Closing, 3); }
        else if (_State == EMars_CookbookState::Opening || _State == EMars_CookbookState::Closing)
        {
            const auto Progress = ck::IsValid(_Clip) && _Clip.GetPlayLength() > 0.0f ?
                _Time / _Clip.GetPlayLength() : 0.0f;
            const auto WasOpening = _State == EMars_CookbookState::Opening;
            DoSet_Pose(WasOpening ? EMars_CookbookState::Closing : EMars_CookbookState::Opening,
                WasOpening ? 3 : 2, 1.0f - Progress);
        }
        else
        { _CloseAfterTurn = true; }
    }

    UFUNCTION()
    void Request_Turn(int32 InDelta)
    {
        if (_State != EMars_CookbookState::Open || InDelta == 0)
        { return; }
        const auto Next = _PageSectionIndex + (InDelta > 0 ? 1 : -1);
        if (Next < 0 || Next >= Get_PageSectionCount())
        { return; }
        DoSet_Pose(InDelta > 0 ? EMars_CookbookState::TurningForward : EMars_CookbookState::TurningReverse,
            InDelta > 0 ? 4 : 5);
        DoApply_Pages();
    }

    UFUNCTION()
    void Request_Close(bool InImmediate = true)
    {
        _CloseAfterTurn = false;
        if (InImmediate)
        {
            DoInitialize_Book();
            DoSet_Pose(EMars_CookbookState::Closed, 0);
            DoRelease_Pages();
        }
        else if (_State != EMars_CookbookState::Closed && _State != EMars_CookbookState::Closing)
        { Request_Toggle(); }
    }

    UFUNCTION(BlueprintPure)
    bool Get_IsOpen() const
    { return _State != EMars_CookbookState::Closed; }

    UFUNCTION(BlueprintPure)
    bool Get_IsTransitioning() const
    { return _State != EMars_CookbookState::Closed && _State != EMars_CookbookState::Open; }

    UFUNCTION(BlueprintPure)
    int32 Get_PageSectionIndex() const
    { return _PageSectionIndex; }

    UFUNCTION(BlueprintPure)
    int32 Get_PageSectionCount() const
    { return Math::Min(LeftPages.Num(), RightPages.Num()); }

    float32 Get_ReadingAlpha() const
    {
        if (_State == EMars_CookbookState::Closed)
        { return 0.0f; }
        if (_State != EMars_CookbookState::Opening && _State != EMars_CookbookState::Closing)
        { return 1.0f; }
        if (ck::Is_NOT_Valid(_Clip) || _Clip.GetPlayLength() <= 0.0f)
        { return 0.0f; }
        auto Progress = Math::Clamp(_Time / _Clip.GetPlayLength(), 0.0f, 1.0f);
        if (_State == EMars_CookbookState::Closing)
        { Progress = 1.0f - Progress; }
        // Matches build_stylized.py's baked cover angle: t*t*(3-2*t).
        return Progress * Progress * (3.0f - 2.0f * Progress);
    }

    private void DoPublish_ReadingPose()
    {
        const auto Alpha = Get_ReadingAlpha();
        if (Math::IsNearlyEqual(Alpha, _PublishedReadingAlpha, 0.00001f))
        { return; }
        _PublishedReadingAlpha = Alpha;
        OnReadingPoseChanged.Broadcast(Alpha);
    }

    private void DoInitialize_Book()
    {
        if (_Initialized)
        { return; }
        // CkUnrealComponent owns TickComponent; disable the engine's second scheduler.
        SetComponentTickEnabled(false);
        SetSkeletalMeshAsset(System::LoadAsset_Blocking(BookMesh));
        TArray<FString> ClipNames;
        ClipNames.Add("Closed");
        ClipNames.Add("Open");
        ClipNames.Add("Opening");
        ClipNames.Add("Closing");
        ClipNames.Add("TurnForward");
        ClipNames.Add("TurnReverse");
        TArray<UAnimSequence> LoadedClips;
        for (auto ClipName : ClipNames)
        {
            const auto Path = f"/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Animations/Cookbook_{ClipName}_AS.Cookbook_{ClipName}_AS";
            auto Clip = System::LoadAsset_Blocking(TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(Path)));
            if (ck::EnsureIfNot(ck::IsValid(Clip), f"[Cookbook] Missing animation {Path}"))
            { return; }
            LoadedClips.Add(Clip);
        }
        _Clips = LoadedClips;
        _Initialized = true;
        for (auto Slot = 2; Slot <= 5; ++Slot)
        { _PageBaseMaterials.Add(GetMaterial(Slot)); }
        DoSet_Pose(EMars_CookbookState::Closed, 0);
    }

    private void DoSet_Pose(EMars_CookbookState InState, int32 InClipIndex, float32 InProgress = 0.0f)
    {
        if (_Clips.IsValidIndex(InClipIndex) == false)
        { return; }
        _State = InState;
        _Clip = _Clips[InClipIndex];
        _Time = Math::Clamp(InProgress, 0.0f, 1.0f) * _Clip.GetPlayLength();
        PlayAnimation(_Clip, false);
        SetPlayRate(0.0f);
        SetPosition(_Time, false);
        DoPublish_ReadingPose();
    }

    private void DoPrepare_Pages()
    {
        if (_PageTextures.IsEmpty() == false || Get_PageSectionCount() == 0)
        { return; }
        if (utils_widget_rasterizer::Get_CanRasterizeOnThisProcess() == false)
        { return; }
        auto Controller = Gameplay::GetPlayerController(0);
        if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController() == false)
        { return; }
        if (_PageMaterials.IsEmpty())
        {
            for (auto Slot = 2; Slot <= 5; ++Slot)
            { _PageMaterials.Add(CreateDynamicMaterialInstance(Slot)); }
        }
        for (auto Section = 0; Section < Get_PageSectionCount(); ++Section)
        {
            for (auto Side = 0; Side < 2; ++Side)
            {
                auto PageClass = System::LoadClassAsset_Blocking(Side == 0 ? LeftPages[Section] : RightPages[Section]);
                if (ck::EnsureIfNot(ck::IsValid(PageClass), f"[Cookbook] Missing page widget {Section}:{Side}"))
                { DoRelease_Pages(); return; }
                auto Widget = Cast<UCk_UserWidget_UE>(WidgetBlueprint::CreateWidget(PageClass, Controller));
                if (ck::EnsureIfNot(ck::IsValid(Widget), f"[Cookbook] Could not create page widget {Section}:{Side}"))
                { DoRelease_Pages(); return; }
                auto Texture = utils_widget_rasterizer::RenderWidgetToTexture(Widget, FIntPoint(1024, 1536),
                    ECk_WidgetRasterizer_GammaCorrection::Disabled);
                if (ck::EnsureIfNot(ck::IsValid(Texture), f"[Cookbook] Could not rasterize page widget {Section}:{Side}"))
                { DoRelease_Pages(); return; }
                _PageWidgets.Add(Widget);
                _PageTextures.Add(Texture);
            }
        }
        DoApply_Pages();
    }

    private void DoApply_Pages()
    {
        if (_PageTextures.Num() != Get_PageSectionCount() * 2 || _PageMaterials.Num() != 4)
        { return; }
        auto Left = _PageSectionIndex;
        auto Right = _PageSectionIndex;
        auto Front = _PageSectionIndex;
        auto Back = _PageSectionIndex;
        if (_State == EMars_CookbookState::TurningForward)
        {
            Right += 1;
            Back += 1;
        }
        else if (_State == EMars_CookbookState::TurningReverse)
        {
            Left -= 1;
            Front -= 1;
        }
        _PageMaterials[0].SetTextureParameterValue(n"BC", _PageTextures[Left * 2]);
        _PageMaterials[1].SetTextureParameterValue(n"BC", _PageTextures[Front * 2 + 1]);
        _PageMaterials[2].SetTextureParameterValue(n"BC", _PageTextures[Back * 2]);
        _PageMaterials[3].SetTextureParameterValue(n"BC", _PageTextures[Right * 2 + 1]);
    }

    private void DoRelease_Pages()
    {
        for (auto Widget : _PageWidgets)
        {
            if (ck::IsValid(Widget))
            { Widget.RemoveFromParent(); }
        }
        // Unreal ignores null texture overrides. Restore the original materials so no MID retains page textures.
        for (auto Index = 0; Index < _PageBaseMaterials.Num(); ++Index)
        { SetMaterial(Index + 2, _PageBaseMaterials[Index]); }
        _PageMaterials.Empty();
        _PageWidgets.Empty();
        _PageTextures.Empty();
    }
}
