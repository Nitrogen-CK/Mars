#include "Mars_Character.h"

#include "Mars_CharacterMovementComponent.h"

AMars_Character::AMars_Character(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer.SetDefaultSubobjectClass<UMars_CharacterMovementComponent>(
		ACharacter::CharacterMovementComponentName))
{
}
