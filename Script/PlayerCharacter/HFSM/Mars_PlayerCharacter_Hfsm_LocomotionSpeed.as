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

namespace utils_locomotion_speed
{
    // Resolved by name: freshly declared tags have no generated GameplayTags:: accessor in a running editor.
    FGameplayTag Get_AttributeName()
    {
        return utils_gameplay_tag::ResolveGameplayTag(n"FloatAttribute.Mars.Player.MovementSpeed");
    }

    FGameplayTag Get_SprintModifierName()
    {
        return utils_gameplay_tag::ResolveGameplayTag(n"AttributeModifier.Mars.Player.Sprint");
    }

    // Composes the attribute on the player. Its value is one moment of movement state, so it is never saved.
    FCk_Handle_FloatAttribute Add(FCk_Handle InPlayer, float32 InWalkSpeed)
    {
        auto Spec = FCk_FloatAttribute_Spec(Get_AttributeName(), InWalkSpeed);
        Spec.Set_PersistValue(ECk_EnableDisable::Disable);
        return utils_float_attribute::Add(InPlayer, Spec, ECk_Replication::Replicates);
    }

    void Apply(FCk_Handle InPlayer, EMars_LocomotionSpeed InSpeed)
    {
        auto Attribute = utils_float_attribute::TryGet(InPlayer, Get_AttributeName());
        if (ck::EnsureIfNot(ck::IsValid(Attribute), f"[LocomotionSpeed] [{InPlayer.ToString()}] has no movement speed attribute"))
        { return; }

        auto Sprint = utils_float_attribute_modifier::TryGet(Attribute, Get_SprintModifierName());
        if (InSpeed == EMars_LocomotionSpeed::Walk)
        {
            if (ck::IsValid(Sprint))
            { utils_float_attribute_modifier::Remove(Sprint); }

            return;
        }

        if (ck::IsValid(Sprint))
        { return; }

        auto Character = Cast<AMars_PlayerCharacter>(ck::ToActor(InPlayer));
        if (ck::EnsureIfNot(ck::IsValid(Character), "[LocomotionSpeed] the context actor is not an AMars_PlayerCharacter"))
        { return; }

        const auto& Speeds = Character.Config.Movement.Speeds;
        if (ck::EnsureIfNot(Speeds.Walk > 0.0f, f"[LocomotionSpeed] Speeds.Walk [{Speeds.Walk}] must be positive to scale it to Sprint"))
        { return; }

        utils_float_attribute_modifier::Add_Revocable(Attribute, Get_SprintModifierName(), ECk_AttributeModifier_Operation::Multiply,
            FCk_FloatAttributeModifier_Spec(Speeds.Sprint / Speeds.Walk, ECk_MinMaxCurrent::Current));
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

        _Attribute = utils_float_attribute::TryGet(Player, utils_locomotion_speed::Get_AttributeName());
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
