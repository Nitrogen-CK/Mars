// Copyright 2024 Suricoon. All Rights Reserved.

#include "Components/BookMenuInteractionComponent.h"
#include "Actors/BookMenuInteractionActor.h"
#include "Components/WidgetComponent.h"
#include "Components/WidgetInteractionComponent.h"
#include "Kismet/KismetMathLibrary.h"

#define LOCTEXT_NAMESPACE "BookMenuPlugin"
// Sets default values for this component's properties
UBookMenuInteractionComponent::UBookMenuInteractionComponent(): InteractionActor(nullptr)
{
	// Set this component to be initialized when the game starts, and to be ticked every frame.  You can turn these features
	// off to improve performance if you don't need them.
	PrimaryComponentTick.bCanEverTick = true;
}


// Called when the game starts
void UBookMenuInteractionComponent::BeginPlay()
{
	Super::BeginPlay();

	if(BookMenuInteractionActorClass == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuInteractionComponentBeginPlay", "BeginPlay: BookMenuInteractionActorClass was null - {0}"), FText::FromString(Message)));
		return;
	}

	ABookMenuInteractionActor * bookMenuActor = GetWorld()->SpawnActorDeferred<ABookMenuInteractionActor>(BookMenuInteractionActorClass, GetComponentTransform(), GetOwner());

	if (!bookMenuActor)
	{
		return;
	}

	bookMenuActor->FinishSpawning(GetComponentTransform());
	bookMenuActor->AttachToComponent(this, FAttachmentTransformRules(EAttachmentRule::SnapToTarget, false));
	InteractionActor = bookMenuActor;
	
}


// Called every frame
void UBookMenuInteractionComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                                  FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	// ...
}

UWidgetInteractionComponent* UBookMenuInteractionComponent::GetWidgetInteractionComponent() const
{
	if(InteractionActor == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuInteractionGetWidgetInteractionComponent", "GetWidgetInteractionComponent: InteractionActor was null - {0}"), FText::FromString(Message)));
		return nullptr;
	}

	return InteractionActor->GetInteractionComponent();
}

#undef LOCTEXT_NAMESPACE