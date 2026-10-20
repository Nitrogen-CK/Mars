// The locomotion speed: the player's replicated FloatAttribute.Mars.Player.MovementSpeed (base Speeds.Walk), which
// UMars_SmTask_MovementSpeedSync (on Alive) pushes into CharacterMovement.MaxWalkSpeed on every copy. The player SM is
// owning-client authoritative (Mars_PlayerCharacter), so every copy enters the owner's Walk / Sprint states and runs these
// tasks' enter: Sprint adds a revocable Multiply modifier (Speeds.Sprint / Speeds.Walk), Walk removes it. The owning
// client's copy is a prediction; the server's is authoritative and replicates, and a client whose value disagrees with the
// server's when it arrives is corrected to it (the attribute's net apply clears the client's revocable modifiers and
// lands on the server's final value). Config.Movement.ClientAuthMaxError absorbs the window while they disagree.

enum EMars_LocomotionSpeed
{
    Walk,
    Sprint
}

// The two speeds the attribute moves between: Walk is its base, Sprint / Walk the sprint modifier's multiplier.
struct FMars_LocomotionSpeed_Spec
{
    UPROPERTY()
    float32 Walk = 420.0f;

    UPROPERTY()
    float32 Sprint = 700.0f;

    FMars_LocomotionSpeed_Spec() {}

    FMars_LocomotionSpeed_Spec(float32 InWalk, float32 InSprint)
    {
        Walk = InWalk;
        Sprint = InSprint;
    }
}

// Both speeds finite and positive.
mixin FMars_Validation Validate(const FMars_LocomotionSpeed_Spec& Self)
{
    if (Math::IsFinite(Self.Walk) == false || Math::IsFinite(Self.Sprint) == false)
    { return FMars_Validation(f"Walk [{Self.Walk}] or Sprint [{Self.Sprint}] is not finite"); }

    if (Self.Walk <= 0.0f || Self.Sprint <= 0.0f)
    { return FMars_Validation(f"Walk [{Self.Walk}] and Sprint [{Self.Sprint}] must be positive"); }

    return FMars_Validation();
}

// Retained from the Spec at Add: what Sprint multiplies the attribute by.
struct FMars_Fragment_LocomotionSpeed_Params
{
    UPROPERTY()
    float32 SprintMultiplier = 1.0f;
}

namespace utils_locomotion_speed
{
    // Composes the attribute on InPlayer. Its value is one moment of movement state, so it is never saved. A spec that
    // fails Validate adds nothing.
    FCk_Handle_FloatAttribute Add(FCk_Handle InPlayer, FMars_LocomotionSpeed_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[LocomotionSpeed] [{InPlayer.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_FloatAttribute(); }

        auto Player = InPlayer;
        auto Params = FMars_Fragment_LocomotionSpeed_Params();
        Params.SprintMultiplier = InSpec.Sprint / InSpec.Walk;
        Player.Add_Fragment(Params);

        auto Spec = FCk_FloatAttribute_Spec(GameplayTags::FloatAttribute_Mars_Player_MovementSpeed, InSpec.Walk);
        Spec.Set_PersistValue(ECk_EnableDisable::Disable);
        return utils_float_attribute::Add(Player, Spec, ECk_Replication::Replicates);
    }

    // InPlayer's sprint modifier is on: it entered Sprint and has not walked, stopped or crouched since.
    bool Get_IsSprinting(FCk_Handle InPlayer)
    {
        auto Attribute = utils_float_attribute::TryGet(InPlayer, GameplayTags::FloatAttribute_Mars_Player_MovementSpeed);
        if (ck::Is_NOT_Valid(Attribute))
        { return false; }

        return ck::IsValid(utils_float_attribute_modifier::TryGet(Attribute, GameplayTags::AttributeModifier_Mars_Player_Sprint));
    }

    void Apply(FCk_Handle InPlayer, EMars_LocomotionSpeed InSpeed)
    {
        auto Attribute = utils_float_attribute::TryGet(InPlayer, GameplayTags::FloatAttribute_Mars_Player_MovementSpeed);
        if (ck::EnsureIfNot(ck::IsValid(Attribute) && InPlayer.Has_Fragment(FMars_Fragment_LocomotionSpeed_Params),
            f"[LocomotionSpeed] [{InPlayer.ToString()}] has no movement speed attribute (utils_locomotion_speed::Add)"))
        { return; }

        auto Sprint = utils_float_attribute_modifier::TryGet(Attribute, GameplayTags::AttributeModifier_Mars_Player_Sprint);
        if (InSpeed == EMars_LocomotionSpeed::Walk)
        {
            if (ck::IsValid(Sprint))
            { utils_float_attribute_modifier::Remove(Sprint); }

            return;
        }

        if (ck::IsValid(Sprint))
        { return; }

        const auto Multiplier = InPlayer.Get_Fragment(FMars_Fragment_LocomotionSpeed_Params).SprintMultiplier;
        utils_float_attribute_modifier::Add_Revocable(Attribute, GameplayTags::AttributeModifier_Mars_Player_Sprint,
            ECk_AttributeModifier_Operation::Multiply, FCk_FloatAttributeModifier_Spec(Multiplier, ECk_MinMaxCurrent::Current));
    }
}

class UMars_SmTask_LocomotionSpeed : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    protected EMars_LocomotionSpeed Speed = EMars_LocomotionSpeed::Walk;

    // Every copy: the owner predicts, the server decides, the attribute's replication reconciles.
    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        utils_locomotion_speed::Apply(ck::Ctx(InHandle), Speed);
    }
}

class UMars_SmTask_LocomotionSpeed_Walk : UMars_SmTask_LocomotionSpeed
{
    default Speed = EMars_LocomotionSpeed::Walk;
}

class UMars_SmTask_LocomotionSpeed_Sprint : UMars_SmTask_LocomotionSpeed
{
    default Speed = EMars_LocomotionSpeed::Sprint;
}

// On Alive: CharacterMovement.MaxWalkSpeed follows the movement speed attribute on every copy.
class UMars_SmTask_MovementSpeedSync : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private ACharacter _Character;
    private FCk_Handle_FloatAttribute _Attribute;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Character = Cast<ACharacter>(ck::ToActor(Player));
        if (ck::EnsureIfNot(ck::IsValid(_Character), "[MovementSpeedSync] the context actor is not an ACharacter"))
        { return; }

        _Attribute = utils_float_attribute::TryGet(Player, GameplayTags::FloatAttribute_Mars_Player_MovementSpeed);
        if (ck::EnsureIfNot(ck::IsValid(_Attribute), f"[MovementSpeedSync] [{Player.ToString()}] has no movement speed attribute"))
        { return; }

        utils_float_attribute::BindTo_OnValueChanged(_Attribute, ECk_MinMaxCurrent::Current,
            FCk_Delegate_FloatAttribute_OnValueChanged(this, n"OnMovementSpeedChanged"));
        Push(float32(_Attribute.Get_FinalValue()));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Attribute))
        {
            utils_float_attribute::UnbindFrom_OnValueChanged(_Attribute, ECk_MinMaxCurrent::Current,
                FCk_Delegate_FloatAttribute_OnValueChanged(this, n"OnMovementSpeedChanged"));
        }

        _Attribute = FCk_Handle_FloatAttribute();
        _Character = nullptr;
    }

    UFUNCTION()
    private void OnMovementSpeedChanged(FCk_Handle InOwner, FCk_Payload_FloatAttribute_OnValueChanged InPayload)
    {
        Push(float32(InPayload.Get_FinalValue()));
    }

    private void Push(float32 InSpeed)
    {
        if (ck::IsValid(_Character) && InSpeed > 0.0f)
        { _Character.CharacterMovement.MaxWalkSpeed = InSpeed; }
    }
}
