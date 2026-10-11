// utils_hit_zone::AttachHurtbox registers a caller-created Probe.Mars.HitZone probe with one zone, and AddHurtbox_Box goes
// through it. Layout: the test entity owns Root A, which owns the zone's entity and a sibling of it; it also owns Root B,
// an unrelated tree. Accepted: a box hurtbox, a probe under the zone, the same probe again (a no-op, no second entry), and
// a probe under the zone's sibling (the crawler-leg layout). Rejected with one ensure each and nothing written (no Link,
// no Hurtboxes entry, the other zone's Link untouched): a probe of another name, a probe already linked to another zone,
// a probe under Root B, and AddHurtbox_Box onto Root B (no node created). Request_ReleaseHurtboxes still destroys every
// registered hurtbox.
class UMars_AutoTest_HitZone_HurtboxRegistration : UCk_AutoTest_Base
{
    private FCk_Handle _Self;
    private FCk_Handle_HitZone _Zone;
    private FCk_Handle_HitZone _OtherZone;
    private FCk_Handle_Transform _ZoneRoot;
    private FCk_Handle_Transform _Sibling;
    private FCk_Handle_Transform _RootB;
    private FCk_Handle_Transform _OtherZoneRoot;
    private TArray<FCk_Handle> _Accepted;

    private FVector _Origin = FVector(0.0, -45000.0, 300.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;

        auto RootA = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(RootA, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);

        auto ZoneEntity = utils_entity_lifetime::Request_CreateEntity(RootA);
        _ZoneRoot = utils_transform::Add(ZoneEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        utils_health::Add(ZoneEntity, FMars_Health_Spec(100.0f));
        _Zone = utils_hit_zone::Add(ZoneEntity, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));

        auto SiblingEntity = utils_entity_lifetime::Request_CreateEntity(RootA);
        _Sibling = utils_transform::Add(SiblingEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 100.0, 0.0)), ECk_Replication::DoesNotReplicate);

        auto OtherZoneEntity = utils_entity_lifetime::Request_CreateEntity(RootA);
        _OtherZoneRoot = utils_transform::Add(OtherZoneEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 200.0, 0.0)), ECk_Replication::DoesNotReplicate);
        utils_health::Add(OtherZoneEntity, FMars_Health_Spec(100.0f));
        _OtherZone = utils_hit_zone::Add(OtherZoneEntity, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));

        auto RootBEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _RootB = utils_transform::Add(RootBEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, -200.0, 0.0)), ECk_Replication::DoesNotReplicate);

        Add_Step("accepted: a box, a probe under the zone (twice), a probe under the zone's sibling", n"Step_Accepted");
        Add_Step("rejected: another name, another zone's probe, another tree, a box on another tree", n"Step_Rejected");
        Add_Step("release the zone's hurtboxes", n"Step_Release");
        Add_Step_WaitUntil("every accepted hurtbox is destroyed", n"Check_AcceptedReleased", 0, 0);
        Add_Step("the zone lists no hurtbox", n"Step_AssertReleased");
        Run_Steps(InHandle);
    }

    private FCk_Handle_Probe Make_Probe(FCk_Handle_Transform InParent, FGameplayTag InName)
    {
        auto Node = utils_scene_node::Create(InParent, FTransform::Identity);
        auto Spec = FCk_Probe_Spec(InName);
        Spec.Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent)
            .Set_MotionType(ECk_MotionType::Kinematic);
        return utils_probe::Add_Box(Node.As_Transform(), FVector(10.0, 10.0, 10.0), Spec);
    }

    private int32 HurtboxCount() const
    {
        return _Zone.Get_Hurtboxes().Num();
    }

    private void AssertLinkedTo(const FCk_Handle& InHurtbox, const FCk_Handle_HitZone& InZone, const FString& InWhat)
    {
        Assert_True(InHurtbox.Has_Fragment(FMars_Fragment_HitZone_Link) && utils_hit_zone::TryGet_Zone(InHurtbox) == InZone,
            f"{InWhat}: links back to its zone");
    }

    UFUNCTION()
    private void Step_Accepted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Box = utils_hit_zone::AddHurtbox_Box(_Zone, _ZoneRoot, FMars_HitZone_Hurtbox(FVector(20.0, 20.0, 20.0), FTransform::Identity));
        Assert_Valid(Box, "AddHurtbox_Box returns the node");
        AssertLinkedTo(Box, _Zone, "the box hurtbox");
        Assert_Equals_Int(HurtboxCount(), 1, "the box is the zone's first hurtbox");
        _Accepted.Add(Box);

        auto UnderZone = Make_Probe(_ZoneRoot, GameplayTags::Probe_Mars_HitZone);
        auto Attached = utils_hit_zone::AttachHurtbox(_Zone, UnderZone);
        Assert_True(ck::IsValid(Attached) && Attached == UnderZone, "a probe under the zone is accepted and returned");
        AssertLinkedTo(Attached, _Zone, "the probe under the zone");
        Assert_Equals_Int(HurtboxCount(), 2, "it is the zone's second hurtbox");
        _Accepted.Add(Attached);

        auto Again = utils_hit_zone::AttachHurtbox(_Zone, UnderZone);
        Assert_True(Again == UnderZone, "registering it again returns it");
        Assert_Equals_Int(HurtboxCount(), 2, "registering it again adds no second entry");

        auto UnderSibling = Make_Probe(_Sibling, GameplayTags::Probe_Mars_HitZone);
        auto SiblingAttached = utils_hit_zone::AttachHurtbox(_Zone, UnderSibling);
        Assert_True(ck::IsValid(SiblingAttached) && SiblingAttached == UnderSibling, "a probe under the zone's sibling is accepted");
        AssertLinkedTo(SiblingAttached, _Zone, "the probe under the zone's sibling");
        Assert_Equals_Int(HurtboxCount(), 3, "it is the zone's third hurtbox");
        _Accepted.Add(SiblingAttached);
    }

    UFUNCTION()
    private void Step_Rejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto WrongName = Make_Probe(_ZoneRoot, GameplayTags::Probe_Mars_Player);
        Assert_Invalid(utils_hit_zone::AttachHurtbox(_Zone, WrongName), "a Probe.Mars.Player probe is rejected");
        FCk_Handle WrongNameEntity = WrongName;
        Assert_False(WrongNameEntity.Has_Fragment(FMars_Fragment_HitZone_Link), "the rejected wrong-name probe has no Link");
        Assert_Equals_Int(HurtboxCount(), 3, "the wrong-name probe was not added");

        auto OtherZones = Make_Probe(_OtherZoneRoot, GameplayTags::Probe_Mars_HitZone);
        auto OtherAttached = utils_hit_zone::AttachHurtbox(_OtherZone, OtherZones);
        Assert_Valid(OtherAttached, "the other zone accepts a probe under itself");
        Assert_Invalid(utils_hit_zone::AttachHurtbox(_Zone, OtherZones), "a probe linked to another zone is rejected");
        AssertLinkedTo(OtherAttached, _OtherZone, "the other zone's probe, after the rejection");
        Assert_Equals_Int(HurtboxCount(), 3, "the other zone's probe was not added");
        Assert_Equals_Int(_OtherZone.Get_Hurtboxes().Num(), 1, "the other zone still lists only its own probe");

        auto OtherTree = Make_Probe(_RootB, GameplayTags::Probe_Mars_HitZone);
        Assert_Invalid(utils_hit_zone::AttachHurtbox(_Zone, OtherTree), "a probe under an unrelated root is rejected");
        FCk_Handle OtherTreeEntity = OtherTree;
        Assert_False(OtherTreeEntity.Has_Fragment(FMars_Fragment_HitZone_Link), "the rejected other-tree probe has no Link");
        Assert_Equals_Int(HurtboxCount(), 3, "the other-tree probe was not added");

        const auto RootBDependents = utils_entity_lifetime::Get_LifetimeDependents(_RootB).Num();
        Assert_Invalid(utils_hit_zone::AddHurtbox_Box(_Zone, _RootB, FMars_HitZone_Hurtbox()), "AddHurtbox_Box onto an unrelated root is rejected");
        Assert_Equals_Int(utils_entity_lifetime::Get_LifetimeDependents(_RootB).Num(), RootBDependents, "the rejected AddHurtbox_Box created no node");
        Assert_Equals_Int(HurtboxCount(), 3, "the rejected box was not added");
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Zone.Request_ReleaseHurtboxes(FMars_Request_HitZone_ReleaseHurtboxes());
    }

    UFUNCTION()
    private void Check_AcceptedReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllGone = true;
        for (auto Hurtbox : _Accepted)
        {
            if (ck::IsValid(Hurtbox))
            { AllGone = false; }
        }

        auto Res = OutResult;
        Res.Set(_Accepted.Num() == 3 && AllGone);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(HurtboxCount(), 0, "the zone lists no hurtbox after the release");
    }
}

// Hand-authored so each rejection's ensure is a required error, raised exactly once.
class AMars_AutoTest_HitZone_HurtboxRegistration_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_HitZone_HurtboxRegistration;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("its probe is named [Probe.Mars.Player], not [Probe.Mars.HitZone]");
        Out.Add("it is already linked to zone");
        Out.Add("its lifetime owners reach neither the zone's entity nor the zone's owner");
        Out.Add("the attach target is owned outside the zone's tree");
        return Out;
    }
}
