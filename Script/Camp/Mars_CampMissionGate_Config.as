// Dimensions are centimeters, independently applied to visuals and explicit Jolt shapes. Keep the placed root at unit scale.
struct FMars_CampMissionGate_Opening
{
    UPROPERTY()
    float64 Width = 400.0;
    UPROPERTY()
    float64 Height = 360.0;
    UPROPERTY()
    float64 FrameThickness = 20.0;
    UPROPERTY()
    float64 FrameDepth = 40.0;
}

struct FMars_CampMissionGate_Bars
{
    // Increase with opening width: pitch is capped at the existing gate's 25cm so a wider seam stays a barrier.
    UPROPERTY()
    int32 Count = 16;
    UPROPERTY()
    float64 Thickness = 8.0;
    UPROPERTY()
    float64 RailHeight = 12.0;
}

struct FMars_CampMissionGate_Motion
{
    UPROPERTY()
    float32 Duration = 1.2f;
    UPROPERTY()
    float64 Clearance = 20.0;
    UPROPERTY()
    float64 ThresholdDepth = 100.0;
}

struct FMars_CampMissionGate_Look
{
    // Intentional unit cube construction, not a missing-asset fallback. Replace only with another centered 100cm box.
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> UnitBox = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/Engine/BasicShapes/Cube.Cube"));
    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> Material = TSoftObjectPtr<UMaterialInterface>(FSoftObjectPath("/Game/Mars/Materials/ProtoGrid/ProtoGrid_Wall_Mars_MI.ProtoGrid_Wall_Mars_MI"));
}

struct FMars_CampMissionGate_Spec
{
    UPROPERTY()
    FMars_CampMissionGate_Opening Opening;
    UPROPERTY()
    FMars_CampMissionGate_Bars Bars;
    UPROPERTY()
    FMars_CampMissionGate_Motion Motion;
    UPROPERTY()
    FMars_CampMissionGate_Look Look;
}

mixin FMars_Validation Validate(const FMars_CampMissionGate_Spec& Self)
{
    if (Math::IsFinite(Self.Opening.Width) == false || Math::IsFinite(Self.Opening.Height) == false
        || Math::IsFinite(Self.Opening.FrameThickness) == false || Math::IsFinite(Self.Opening.FrameDepth) == false
        || Math::IsFinite(Self.Bars.Thickness) == false || Math::IsFinite(Self.Bars.RailHeight) == false
        || Math::IsFinite(Self.Motion.Duration) == false || Math::IsFinite(Self.Motion.Clearance) == false
        || Math::IsFinite(Self.Motion.ThresholdDepth) == false)
    { return FMars_Validation("Gate dimensions and motion must be finite"); }
    if ((Self.Opening.Width > 0.0 && Self.Opening.Height > 0.0 && Self.Opening.FrameThickness > 0.0 && Self.Opening.FrameDepth > 0.0) == false)
    { return FMars_Validation("Opening dimensions must be positive"); }
    if (Self.Bars.Count < 2 || Self.Bars.Count > 256 || (Self.Bars.Thickness > 0.0 && Self.Bars.RailHeight > 0.0) == false)
    { return FMars_Validation("Bars need 2..256 members and positive thickness and rail height"); }
    if ((Self.Bars.Thickness < Self.Opening.Width / Self.Bars.Count && Self.Bars.RailHeight < Self.Opening.Height * 0.4) == false)
    { return FMars_Validation("Bar thickness and rails must fit the opening"); }
    if (Self.Opening.Width / Self.Bars.Count > 25.0)
    { return FMars_Validation("Bar pitch exceeds 25cm; increase Bars.Count with Opening.Width"); }
    if ((Self.Motion.Duration >= 0.0f && Self.Motion.Clearance >= 0.0 && Self.Motion.ThresholdDepth > 0.0) == false)
    { return FMars_Validation("Motion duration and clearance must be non-negative, threshold depth positive"); }
    if (Self.Look.UnitBox.IsNull() || Self.Look.Material.IsNull())
    { return FMars_Validation("Look.UnitBox and Look.Material must be set"); }
    return FMars_Validation();
}

namespace utils_camp_mission_gate
{
    // Only the authoritative, replicated party selection participates. Widget previews never enter this API.
    EMars_Gate_Position Get_Position(const FMars_CampPartyState& InParty, UMars_ServiceCatalog InCatalog)
    {
        if (ck::Is_NOT_Valid(InCatalog))
        { return EMars_Gate_Position::Closed; }
        auto Service = InCatalog.Find(InParty.ServiceId);
        return ck::IsValid(Service) && Service.Destination.IsNull() == false
            ? EMars_Gate_Position::Open : EMars_Gate_Position::Closed;
    }

    void Request_Project(FCk_Handle_Gate& InGate, const FMars_CampPartyState& InParty, UMars_ServiceCatalog InCatalog)
    {
        if (ck::IsValid(InGate))
        { InGate.Request_SetPosition(FMars_Request_Gate_SetPosition(Get_Position(InParty, InCatalog))); }
    }
}
