// Whether a struck forage source's knock body is there only while it holds a yield.
enum EMars_ForageSource_KnockPresence
{
    // The body is the yield itself (a vine's fruit): a harvested source has nothing there to knock or to bounce off.
    FollowsYield,
    // The body is part of the source (a censer's bob): it stays solid whether the source holds a yield or not.
    Permanent
}

// The knock body a struck forage source composes: a sphere on its own node under the parent it is added to.
struct FMars_ForageSource_KnockBody
{
    FTransform Offset = FTransform::Identity;

    float32 Radius = 20.0f;

    ECk_MotionType MotionType = ECk_MotionType::Static;

    EMars_ForageSource_KnockPresence Presence = EMars_ForageSource_KnockPresence::FollowsYield;
}

// The shared adapter of a struck forage source: a thrown item closing on its knock body at Get_KnockMinSpeed() or more
// releases a yield; exhausting it disables its hit zone and hides its yield mesh (and removes a FollowsYield knock body);
// replenishing heals it and restores all three. Subclasses compose the forage, the health, the zone and their geometry,
// then call AddKnockBody and BindForage.
UCLASS(Abstract)
class UMars_ForageSource_EntityScript : UCk_GenericEntityScript_UE
{
    UPROPERTY(ExposeOnSpawn)
    FMars_Anchor_Context Anchor;

    protected FCk_Handle_Forage _Forage;
    protected FCk_Handle_Health _Health;
    protected FCk_Handle_HitZone _Zone;

    // Created after construction; invalid until then, under nullrhi, and without visuals.
    protected FCk_Handle_UnrealComponent _YieldMesh;

    private FCk_Handle_Transform _KnockParent;
    private FMars_ForageSource_KnockBody _KnockBody;
    private FCk_Handle_SceneNode _KnockNode;

    // Closing speed (uu/s) a thrown world item needs to knock a yield out. Subclasses return their placed property.
    protected float32 Get_KnockMinSpeed() const
    {
        return 0.0f;
    }

    protected void AddKnockBody(FCk_Handle_Transform& InParent, FMars_ForageSource_KnockBody InBody)
    {
        _KnockParent = InParent;
        _KnockBody = InBody;
        CreateKnockBody();
    }

    protected void BindForage()
    {
        _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnForageExhausted"));
        _Forage.BindTo_OnReplenished(FMars_Delegate_Forage_OnReplenished(this, n"OnForageReplenished"));
    }

    private void CreateKnockBody()
    {
        _KnockNode = utils_scene_node::Create(_KnockParent, _KnockBody.Offset);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Sphere);
        Shape.Set_Radius(_KnockBody.Radius);
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(_KnockBody.MotionType);
        BodySpec.Set_CollisionProfileName(collision::profile::BlockAll);
        auto Body = utils_jolt_body::Add(_KnockNode.H(), BodySpec);
        utils_jolt_body::BindTo_OnJoltBodyContactAdded(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnKnockBodyContact"));
    }

    // Removed with its node rather than re-profiled: a NoCollision profile has no Jolt layer to move the body to.
    private void DestroyKnockBody()
    {
        if (ck::IsValid(_KnockNode))
        { utils_entity_lifetime::Request_DestroyEntity(_KnockNode.H()); }

        _KnockNode = FCk_Handle_SceneNode();
    }

    // The component is created after construction; until then (and under nullrhi) there is nothing to hide.
    private void SetYieldVisible(bool InVisible)
    {
        if (ck::Is_NOT_Valid(_YieldMesh))
        { return; }

        auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(_YieldMesh));
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        Mesh.SetVisibility(InVisible);
    }

    // Whether a FollowsYield knock body is there now; a Permanent one always is.
    protected bool Get_HasKnockBody() const
    {
        return ck::IsValid(_KnockNode);
    }

    UFUNCTION()
    private void OnKnockBodyContact(FCk_Handle_JoltBody InBody, FCk_JoltBody_Payload_OnContact InPayload)
    {
        if (utils_forage::Get_IsKnock(InPayload, Get_KnockMinSpeed()) == false)
        { return; }

        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Knock));
    }

    UFUNCTION()
    private void OnForageExhausted(FCk_Handle_Forage InForage)
    {
        _Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Disable));
        SetYieldVisible(false);

        if (_KnockBody.Presence == EMars_ForageSource_KnockPresence::FollowsYield)
        { DestroyKnockBody(); }
    }

    UFUNCTION()
    private void OnForageReplenished(FCk_Handle_Forage InForage)
    {
        _Health.Request_Heal(FMars_Request_Health_Heal(_Health.Get_Max()));
        _Zone.Request_SetEnabled(FMars_Request_HitZone_SetEnabled(ECk_EnableDisable::Enable));
        SetYieldVisible(true);

        if (_KnockBody.Presence == EMars_ForageSource_KnockPresence::FollowsYield && ck::Is_NOT_Valid(_KnockNode))
        { CreateKnockBody(); }
    }
}
