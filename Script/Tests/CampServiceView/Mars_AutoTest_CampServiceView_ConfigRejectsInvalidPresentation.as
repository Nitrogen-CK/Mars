// Pure presentation validation: the shipped asset must explicitly retain the nested defaults, and every bad group rejects.
// Fresh mutable configs copy the shipped asset before each change; the shared asset is never modified.
class UMars_AutoTest_CampServiceView_ConfigRejectsInvalidPresentation : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("shipped asset initialized its nested presentation groups", n"Step_ShippedValid");
        Add_Step("missing references and unsafe parchment transforms reject", n"Step_RefsAndOffset");
        Add_Step("reading size must be finite and positive", n"Step_ReadingSize");
        Add_Step("blend and FOV boundaries reject invalid values", n"Step_View");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ShippedValid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Config = mars::Mars_StewardService_Config;
        Assert_True(ck::IsValid(Config), "shipped config exists");
        Assert_True(Config.Validate().IsValid(), "shipped asset is a valid initialized presentation");
        const auto ParchmentDefaults = FMars_StewardService_Parchment();
        const auto ViewDefaults = FMars_StewardService_View();
        Assert_True(Config.Parchment.Offset.Equals(ParchmentDefaults.Offset), "asset block retained the default parchment transform");
        Assert_True(Config.Parchment.ReadingSizeCm.Equals(ParchmentDefaults.ReadingSizeCm), "asset block retained the reading rectangle");
        Assert_True(Math::Abs(Config.View.BlendInSeconds - ViewDefaults.BlendInSeconds) < 0.0001f,
            "asset block retained blend-in duration");
        Assert_True(Math::Abs(Config.View.BlendOutSeconds - ViewDefaults.BlendOutSeconds) < 0.0001f,
            "asset block retained blend-out duration");
        Assert_True(Math::Abs(Config.View.FieldOfView - ViewDefaults.FieldOfView) < 0.0001f,
            "asset block retained field of view");
        Assert_True(MakeConfig().Validate().IsValid(), "explicit copy into a standalone config is valid");
    }

    UFUNCTION()
    private void Step_RefsAndOffset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Config = MakeConfig();
        Config.Parchment.BodyMesh = TSoftObjectPtr<USkeletalMesh>();
        Reject(Config, "required");
        Config = MakeConfig();
        Config.Parchment.Mesh = TSoftObjectPtr<UStaticMesh>();
        Reject(Config, "required");
        Config = MakeConfig();
        Config.Parchment.PresentLoop = TSoftObjectPtr<UAnimSequence>();
        Reject(Config, "required");
        Config = MakeConfig();
        Config.WidgetClass = TSoftClassPtr<UMars_ChalkService_Widget>();
        Reject(Config, "required");
        Config = MakeConfig();
        Config.Parchment.Offset = FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(2.0, 1.0, 1.0));
        Reject(Config, "unit scale");
        Config = MakeConfig();
        Config.Parchment.Offset = FTransform(FVector(Math::Sqrt(-1.0), 0.0, 0.0));
        Reject(Config, "finite");
    }

    UFUNCTION()
    private void Step_ReadingSize(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Config = MakeConfig();
        Config.Parchment.ReadingSizeCm = FVector2D(0.0, 50.0);
        Reject(Config, "Reading dimensions");
        Config = MakeConfig();
        Config.Parchment.ReadingSizeCm = FVector2D(80.0, -1.0);
        Reject(Config, "Reading dimensions");
        Config = MakeConfig();
        Config.Parchment.ReadingSizeCm = FVector2D(Math::Sqrt(-1.0), 50.0);
        Reject(Config, "Reading dimensions");
        Config = MakeConfig();
        Config.Parchment.ReadingSizeCm = FVector2D(80.0, Math::Sqrt(-1.0));
        Reject(Config, "Reading dimensions");
    }

    UFUNCTION()
    private void Step_View(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Config = MakeConfig();
        Config.View.BlendInSeconds = 0.0f;
        Config.View.BlendOutSeconds = 0.0f;
        Assert_True(Config.Validate().IsValid(), "zero-duration cuts are allowed");
        Config = MakeConfig();
        Config.View.BlendInSeconds = -0.01f;
        Reject(Config, "blend durations");
        Config = MakeConfig();
        Config.View.BlendOutSeconds = -0.01f;
        Reject(Config, "blend durations");
        Config = MakeConfig();
        Config.View.BlendInSeconds = float32(Math::Sqrt(-1.0));
        Reject(Config, "blend durations");
        Config = MakeConfig();
        Config.View.BlendOutSeconds = float32(Math::Sqrt(-1.0));
        Reject(Config, "blend durations");
        Config = MakeConfig();
        Config.View.FieldOfView = 1.0f;
        Reject(Config, "field of view");
        Config = MakeConfig();
        Config.View.FieldOfView = 170.0f;
        Reject(Config, "field of view");
        Config = MakeConfig();
        Config.View.FieldOfView = float32(Math::Sqrt(-1.0));
        Reject(Config, "field of view");
        Config = MakeConfig();
        Config.View.FieldOfView = 1.01f;
        Assert_True(Config.Validate().IsValid(), "FOV just above lower boundary is allowed");
        Config.View.FieldOfView = 169.99f;
        Assert_True(Config.Validate().IsValid(), "FOV just below upper boundary is allowed");
    }

    private UMars_StewardService_Config MakeConfig()
    {
        auto Config = Cast<UMars_StewardService_Config>(NewObject(this, UMars_StewardService_Config));
        Config.Parchment = mars::Mars_StewardService_Config.Parchment;
        Config.View = mars::Mars_StewardService_Config.View;
        Config.WidgetClass = mars::Mars_StewardService_Config.WidgetClass;
        return Config;
    }

    private void Reject(UMars_StewardService_Config InConfig, const FString& InRule)
    {
        const auto Validation = InConfig.Validate();
        Assert_False(Validation.IsValid(), f"invalid presentation rejects [{InRule}]");
        Assert_True(Validation.Get_Error().Contains(InRule), f"rejection names [{InRule}], got [{Validation.Get_Error()}]");
    }
}
