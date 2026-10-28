// Copyright 2024 Suricoon. All Rights Reserved.

#include "Components/BookMenuComponent.h"
#include "Actors/BookMenuInteractionActor.h"
#include "Components/BookMenuInteractionComponent.h"

#define LOCTEXT_NAMESPACE "BookMenuPlugin"
// Sets default values for this component's properties
UBookMenuComponent::UBookMenuComponent(): BookMenuActor(nullptr), BookMenuData(nullptr)
{
	// Set this component to be initialized when the game starts, and to be ticked every frame.  You can turn these features
	// off to improve performance if you don't need them.
	PrimaryComponentTick.bCanEverTick = true;
}

void UBookMenuComponent::SetBookMenuData(UBookMenuData* InBookMenuData)
{
	if(BookMenuActor == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("SetBookMenuData", "SetBookMenuData: BookMenuActor was null - {0}"), FText::FromString(Message)));
		return;
	}

	BookMenuActor->SetBookMenuData(InBookMenuData);
	BookMenuData = BookMenuActor->BookMenuData;
	
}

UBookMenuData* UBookMenuComponent::GetBookMenuData() const
{
	if(BookMenuActor == nullptr)
	{
		return nullptr;
	}
	
	return BookMenuActor->GetBookMenuData();
}

int32 UBookMenuComponent::GetCurrentPageSectionIndex() const
{
	if(BookMenuActor == nullptr)
	{
		return -1;
	}

	return BookMenuActor->GetCurrentPageSectionIndex();
	
}

int32 UBookMenuComponent::GetPendingPageSectionIndex() const
{
	if(BookMenuActor == nullptr)
	{
		return -1;
	}

	return BookMenuActor->GetPendingPageSectionIndex();
}

int32 UBookMenuComponent::GetCurrentPageIndex() const
{
	if(BookMenuActor == nullptr)
	{
		return -1;
	}

	return BookMenuActor->GetCurrentPageIndex();
}

bool UBookMenuComponent::GetBookIsOpen() const
{
	if(BookMenuActor == nullptr)
	{
		return false;
	}

	return BookMenuActor->GetBookIsOpen();
}

bool UBookMenuComponent::GetBookShouldOpen() const
{
	if(BookMenuActor == nullptr)
	{
		return false;
	}

	return BookMenuActor->GetBookShouldOpen();
}

bool UBookMenuComponent::GetBookShouldClose() const
{
	if(BookMenuActor == nullptr)
	{
		return false;
	}

	return BookMenuActor->GetBookShouldClose();
}

TMap<int32, FPageSectionDataStruct> UBookMenuComponent::GetPageSections() const
{
	if(BookMenuActor == nullptr)
	{
		return TMap<int32, FPageSectionDataStruct>();
	}

	return BookMenuActor->GetPageSections();
}

void UBookMenuComponent::RegisterInteractionComponent(UBookMenuInteractionComponent* InInteractionComponent)
{
	if(BookMenuActor == nullptr || InInteractionComponent == nullptr || InInteractionComponent->InteractionActor == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuComponentRegisterInteractionComponent", "RegisterInteractionComponent: BookMenuActor, InInteractionComponent or the InteractionActor of the INInteractionComponent was null - {0}"), FText::FromString(Message)));
		return;
	}

	BookMenuActor->SetInteractionActor(InInteractionComponent->InteractionActor);
}

void UBookMenuComponent::RegisterInteractionActor(ABookMenuInteractionActor* InteractionActor)
{
	if(BookMenuActor == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuComponentRegisterInteractionActor", "RegisterInteractionActor: BookMenuActor was null - {0}"), FText::FromString(Message)));
		return;
	}

	BookMenuActor->SetInteractionActor(InteractionActor);
	
}

bool UBookMenuComponent::Interact(FVector Start, FVector End, EExecResultBookMenu &OutResult, bool bDebugTrace, ECollisionChannel TraceChannel)
{
	if(BookMenuActor == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuComponentInteract", "Interact: BookMenuActor was null - {0}"), FText::FromString(Message)));
		
		return false;
	}

	return BookMenuActor->Interact(Start, End, OutResult, bDebugTrace, TraceChannel);
}

bool UBookMenuComponent::InteractExt(FVector Start, FVector End, EExecResultBookMenu& OutResult,
	FVector2D& OutUVCoordinates, bool bDebugTrace, ECollisionChannel TraceChannel)
{
	if(BookMenuActor == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuComponentInteract", "Interact: BookMenuActor was null - {0}"), FText::FromString(Message)));
		
		return false;
	}

	return BookMenuActor->InteractExt(Start, End, OutResult, OutUVCoordinates ,bDebugTrace, TraceChannel);
}

bool UBookMenuComponent::SetKeyboardFocus(int32 InPageIndex, EExecResultBookMenu& OutResult)
{
	if(BookMenuActor == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("SetKeyboardFocus", "SetKeyboardFocus: BookMenuActor was null - {0}"), FText::FromString(Message)));
		
		return false;
	}

	return BookMenuActor->SetKeyboardFocus(InPageIndex, OutResult);
}

// Called when the game starts
void UBookMenuComponent::BeginPlay()
{
	Super::BeginPlay();

	if(BookMenuActorClass == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuComponentBeginPlay", "BeginPlay: BookMenuActorClass was null - {0}"), FText::FromString(Message)));
		return;
	}

	ABookMenuActor * bookMenuActor = GetWorld()->SpawnActorDeferred<ABookMenuActor>(BookMenuActorClass, GetComponentTransform(), GetOwner());

	if (!bookMenuActor)
	{
		return;
	}

	if(BookMenuData != nullptr)
	{
		bookMenuActor->BookMenuData = BookMenuData;
	}

	BookMenuActor = bookMenuActor;
	bookMenuActor->FinishSpawning(GetComponentTransform());
	bookMenuActor->AttachToComponent(this, FAttachmentTransformRules(EAttachmentRule::SnapToTarget, false));
	
}


// Called every frame
void UBookMenuComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                       FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
}



#undef LOCTEXT_NAMESPACE