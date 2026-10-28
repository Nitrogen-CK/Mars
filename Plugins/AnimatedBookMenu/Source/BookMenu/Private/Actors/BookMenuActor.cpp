// Copyright 2024 Suricoon. All Rights Reserved.

#include "Actors/BookMenuActor.h"
#include "BookMenuStatics.h"
#include "Actors/BookMenuInteractionActor.h"
#include "Components/BookMenuInteractionComponent.h"
#include "Components/BoxComponent.h"
#include "Components/WidgetComponent.h"
#include "DataAssets/BookMenuData.h"
#include "Components/SkeletalMeshComponent.h"

#define LOCTEXT_NAMESPACE "BookMenuPlugin"

void ABookMenuActor::ClearBookData()
{
	if(GetAnimInstance() != nullptr)
	{
		GetAnimInstance()->Pause();

		if(InteractionActor != nullptr)
		{
		
			GetAnimInstance()->ClearPageSectionOneWidgets();
			GetAnimInstance()->ClearPageSectionTwoWidgets();
		}
	}

	SkeletalMeshComponent->SetSkeletalMesh(nullptr);
	SkeletalMeshComponent->SetAnimInstanceClass(nullptr);

}

void ABookMenuActor::InitBookData()
{
	if(BookMenuData == nullptr)
	{
		return;
	}
	
	if(BookMenuData->SkeletalMesh == nullptr || BookMenuData->AnimInstanceClass.Get() == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Warning(FText::Format(LOCTEXT("BookMenuActorInvalidBookMenuData", "No or incomplete BookMenuData - {0}"), FText::FromString(Message)));
		return;
	}
	
	SkeletalMeshComponent->SetSkeletalMesh(BookMenuData->SkeletalMesh);
	SkeletalMeshComponent->SetAnimInstanceClass(BookMenuData->AnimInstanceClass);
	SkeletalMeshComponent->SetRelativeTransform(StaticMeshComponent->GetRelativeTransform());

	if(UBookMenuAnimInstance * AnimInstance = Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance()); AnimInstance != nullptr)
	{
		AnimInstance->Init(BookMenuData, this);

		if(BookMenuData->bBookBeginsPlayOpen)
		{
			AnimInstance->OpenBookAtWithoutAnimation(BookMenuData->StartPageSection);
		}
	}

	if(InteractionActor != nullptr)
	{
		if(GetAnimInstance() == nullptr)
		{
			return;
		}

		//GetAnimInstance()->SetWidgetComponent(InteractionActor->GetPageWidgetComponent());
		GetAnimInstance()->SetInteractionActor(InteractionActor);
		GetAnimInstance()->DrawSize = BookMenuData->DrawSize;
		InteractionActor->DrawSize = BookMenuData->DrawSize;
	}
}

ABookMenuActor::ABookMenuActor()
{
	SetCanBeDamaged(false);
	PrimaryActorTick.bCanEverTick = true;

	DefaultSceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("DefaultSceneRoot"));
	RootComponent = DefaultSceneRoot;

	const FAttachmentTransformRules AttachmentRules = FAttachmentTransformRules(EAttachmentRule::KeepRelative, false);

	SkeletalMeshComponent = CreateDefaultSubobject<USkeletalMeshComponent>(TEXT("SkeletalMeshComponent"));
	SkeletalMeshComponent->AttachToComponent(RootComponent,AttachmentRules);
	SkeletalMeshComponent->SetRelativeRotation(FRotator(0.f,90.f,90.f));
	SkeletalMeshComponent->Mobility = EComponentMobility::Movable;
	SkeletalMeshComponent->SetGenerateOverlapEvents(false);
	SkeletalMeshComponent->SetIsReplicated(false);
	SkeletalMeshComponent->SetHiddenInGame(false);
	SkeletalMeshComponent->bCastDynamicShadow = true;
	SkeletalMeshComponent->SetCollisionProfileName(UCollisionProfile::NoCollision_ProfileName);
	SkeletalMeshComponent->SetCanEverAffectNavigation(false);

	StaticMeshComponent = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("StaticMeshComponent"));
	StaticMeshComponent->AttachToComponent(RootComponent,AttachmentRules);
	StaticMeshComponent->SetRelativeRotation(FRotator(0.f,90.f,90.f));
	StaticMeshComponent->Mobility = EComponentMobility::Movable;
	StaticMeshComponent->SetGenerateOverlapEvents(false);
	StaticMeshComponent->SetIsReplicated(false);
	StaticMeshComponent->SetHiddenInGame(true);
	StaticMeshComponent->bCastDynamicShadow = false;
	StaticMeshComponent->SetCollisionProfileName(UCollisionProfile::BlockAll_ProfileName);
	StaticMeshComponent->SetCanEverAffectNavigation(false);

	LeftPageCollision = CreateDefaultSubobject<UBoxComponent>(TEXT("LeftPageCollision"));
	LeftPageCollision->AttachToComponent(StaticMeshComponent,AttachmentRules);
	LeftPageCollision->InitBoxExtent(FVector(10.f, 10.f, 10.f));
	LeftPageCollision->SetCollisionProfileName(UCollisionProfile::NoCollision_ProfileName);
	
	LeftPageCollision->SetCollisionObjectType(ECC_WorldStatic);
	LeftPageCollision->SetCollisionResponseToAllChannels(ECR_Overlap);
	LeftPageCollision->SetCollisionEnabled(ECollisionEnabled::QueryOnly);

	RightPageCollision = CreateDefaultSubobject<UBoxComponent>(TEXT("RightPageCollision"));
	RightPageCollision->AttachToComponent(StaticMeshComponent, AttachmentRules);
	RightPageCollision->InitBoxExtent(FVector(10.f, 10.f, 10.f));
	RightPageCollision->SetCollisionProfileName(UCollisionProfile::NoCollision_ProfileName);
	RightPageCollision->SetCollisionObjectType(ECC_WorldStatic);
	RightPageCollision->SetCollisionResponseToAllChannels(ECR_Overlap);
	RightPageCollision->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
}

void ABookMenuActor::BeginPlay()
{
	Super::BeginPlay();
	
	//initialize the book in case we have default book menu data
	InitBookData();
	
}

UBookMenuData* ABookMenuActor::GetBookMenuData() const
{
	if(BookMenuData == nullptr)
	{
		return nullptr;
	}
	
	//Duplicate this object and set the new outer
	FObjectDuplicationParameters param = FObjectDuplicationParameters(BookMenuData, GetOuter());
	param.DestClass = BookMenuData->GetClass();
	UBookMenuData * clone = Cast<UBookMenuData>(StaticDuplicateObjectEx(param));

	GetPageSections().GenerateValueArray(clone->PageSections);
	
	return clone;
}

void ABookMenuActor::SetBookMenuData(UBookMenuData* InBookMenuData)
{
	//reset previous book
	ClearBookData();

	UBookMenuData * clone = nullptr;
	
	if(InBookMenuData != nullptr)
	{
		//Duplicate this object and set the new outer
		FObjectDuplicationParameters param = FObjectDuplicationParameters(InBookMenuData, GetOuter());
		param.DestClass = InBookMenuData->GetClass();
		clone = Cast<UBookMenuData>(StaticDuplicateObjectEx(param));
	}
	
	//set new book data
	BookMenuData = clone;

	//initialize the new book
	InitBookData();
}

int32 ABookMenuActor::GetCurrentPageSectionIndex() const
{
	if(GetAnimInstance() == nullptr)
	{
		return -1;
	}

	return GetAnimInstance()->CurrentPageSectionIndex;
}



int32 ABookMenuActor::GetPendingPageSectionIndex() const
{
	if(GetAnimInstance() == nullptr || BookMenuData == nullptr)
	{
		return -1;
	}

	return GetAnimInstance()->PendingPageSectionIndex;
}

int32 ABookMenuActor::GetCurrentPageIndex() const
{
	if(GetAnimInstance() == nullptr || BookMenuData == nullptr)
	{
		return -1;
	}

	return GetAnimInstance()->CurrentPageIndex;
}

bool ABookMenuActor::GetBookIsOpen() const
{
	if(GetAnimInstance() == nullptr || BookMenuData == nullptr)
	{
		return false;
	}

	return GetAnimInstance()->bBookIsOpen;
}

bool ABookMenuActor::GetBookShouldOpen() const
{
	if(GetAnimInstance() == nullptr || BookMenuData == nullptr)
	{
		return false;
	}

	return GetAnimInstance()->bBookShouldOpen;
}

bool ABookMenuActor::GetBookShouldClose() const
{
	if(GetAnimInstance() == nullptr || BookMenuData == nullptr)
	{
		return false;
	}

	return GetAnimInstance()->bBookShouldClose;
}

TMap<int32,FPageSectionDataStruct> ABookMenuActor::GetPageSections() const
{
	if(GetAnimInstance() == nullptr || BookMenuData == nullptr)
	{
		return TMap<int32,FPageSectionDataStruct>();
	}

	return GetAnimInstance()->PageSections;
}

ABookMenuInteractionActor* ABookMenuActor::GetInteractionActor() const
{
	return InteractionActor;
}

void ABookMenuActor::RegisterInteractionComponent(UBookMenuInteractionComponent* InInteractionComponent)
{
	if(InInteractionComponent == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("UBookMenuActorRegisterInteractionComponent", "RegisterInteractionComponent: InInteractionComponent was null - {0}"), FText::FromString(Message)));
		return;
	}

	SetInteractionActor(InInteractionComponent->InteractionActor);
}

void ABookMenuActor::RegisterInteractionActor(ABookMenuInteractionActor* InInteractionActor)
{
	SetInteractionActor(InInteractionActor);
}

void ABookMenuActor::SetInteractionActor(ABookMenuInteractionActor* InInteractionActor)
{
	if(InInteractionActor == InteractionActor)
	{
		return;
	}

	if(InteractionActor != nullptr)
	{
		if(GetAnimInstance() != nullptr)
		{
			GetAnimInstance()->SetInteractionActor(nullptr);
		}
	}	
	
	InteractionActor = InInteractionActor;

	if(GetAnimInstance() == nullptr)
	{
		return;
	}

	if(InteractionActor == nullptr)
	{
		GetAnimInstance()->SetInteractionActor(nullptr);
		return;
	}

	GetAnimInstance()->SetInteractionActor(InteractionActor);
	GetAnimInstance()->DrawSize = BookMenuData->DrawSize;
	InteractionActor->DrawSize = BookMenuData->DrawSize;
	
}

void ABookMenuActor::JumpToPageSection(int32 SectionIndex)
{
	if(BookMenuData == nullptr)
	{
		return;
	}
	
	UBookMenuAnimInstance * animInstance = Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance());

	if(animInstance == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuActorJumpToSectionInvalidAnimInstance", "JumpToPageSection: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return;
	}

	animInstance->JumpToPageSection(SectionIndex);
}

void ABookMenuActor::OpenBookAt(int32 SectionIndex)
{
	if(BookMenuData == nullptr)
	{
		return;
	}
	
	UBookMenuAnimInstance * AnimInstance = Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance());

	if(AnimInstance == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuActorOpenBookAtInvalidAnimInstance", "OpenBookAt: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return;
	}

	AnimInstance->OpenBookAt(SectionIndex);
}

void ABookMenuActor::CloseBook()
{
	if(BookMenuData == nullptr)
	{
		return;
	}
	
	UBookMenuAnimInstance * AnimInstance = Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance());

	if(AnimInstance == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuActorCloseBookInvalidAnimInstance", "CloseBook: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return;
	}

	AnimInstance->CloseBook();
}

void ABookMenuActor::PauseBookUpdate()
{
	if(BookMenuData == nullptr)
	{
		return;
	}
	
	if(GetAnimInstance() == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuActorPauseBookUpdateInvalidAnimInstance", "PauseBookUpdate: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return;
	}

	GetAnimInstance()->Pause();
}

void ABookMenuActor::ResumeBookUpdate()
{

	if(BookMenuData == nullptr)
	{
		return;
	}
	
	if(GetAnimInstance() == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuActorResumeBookUpdateInvalidAnimInstance", "ResumeBookUpdate: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return;
	}

	//can only resume if the book is already open or opening
	if(GetAnimInstance()->bBookIsOpen || GetAnimInstance()->bBookShouldOpen)
	{
		GetAnimInstance()->Resume();
	}
}

bool ABookMenuActor::Interact(const FVector Start, const FVector End, EExecResultBookMenu &OutResult, const bool bDebugTrace, const ECollisionChannel TraceChannel)
{
	OutResult = EExecResultBookMenu::Failed;
	
	if(InteractionActor == nullptr || BookMenuData == nullptr)
	{
		return false;
	}
		
	FVector2D UVCoordinates;
	int32 OutPageIndex;

	if(!UBookMenuStatics::BookUvTrace(this, this, Start,End,UVCoordinates, OutPageIndex, bDebugTrace, TraceChannel))
	{
		return false;
	}

	UBookMenuAnimInstance * AnimInstance = Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance());
	if(AnimInstance == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuActorInteractInvalidAnimInstance", "Interact: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return false;
	}

	AnimInstance->CurrentPageIndex = OutPageIndex;
	if(!InteractionActor->MovePointer(UVCoordinates,bDebugTrace))
	{
		return false;
	}

	OutResult = EExecResultBookMenu::Success;
	return true;
}

bool ABookMenuActor::InteractExt(FVector Start, FVector End, EExecResultBookMenu& OutResult,
	FVector2D& OutUVCoordinates, bool bDebugTrace, ECollisionChannel TraceChannel)
{
	OutResult = EExecResultBookMenu::Failed;
	OutUVCoordinates = FVector2D();
	
	if(InteractionActor == nullptr || BookMenuData == nullptr)
	{
		return false;
	}
		
	FVector2D UVCoordinates;
	int32 OutPageIndex;

	if(!UBookMenuStatics::BookUvTrace(this, this, Start,End,UVCoordinates, OutPageIndex, bDebugTrace, TraceChannel))
	{
		
		return false;
	}

	OutUVCoordinates = UVCoordinates;

	UBookMenuAnimInstance * AnimInstance = Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance());
	if(AnimInstance == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("BookMenuActorInteractInvalidAnimInstance", "Interact: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return false;
	}

	AnimInstance->CurrentPageIndex = OutPageIndex;
	if(!InteractionActor->MovePointer(UVCoordinates,bDebugTrace))
	{
		return false;
	}

	OutResult = EExecResultBookMenu::Success;
	return true;
}

bool ABookMenuActor::SetKeyboardFocus(int32 InPageIndex, EExecResultBookMenu& OutResult, bool bDebugTrace)
{
	if(InteractionActor == nullptr || BookMenuData == nullptr)
	{
		return false;
	}

	//Bring the pointer in a safe location to not fight against the keyboard focus
	InteractionActor->ResetPointer(bDebugTrace);
	
	if(InPageIndex > 1 || InPageIndex < 0)
	{
		OutResult = EExecResultBookMenu::Failed;
		return false;
	}

	UBookMenuAnimInstance * AnimInstance = Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance());
	if(AnimInstance == nullptr)
	{
		const FString Message = FString::Printf(TEXT("%s."), *this->GetName());
		FMessageLog("PIE").Error(FText::Format(LOCTEXT("SetKeyboardFocus", "SetKeyboardFocus: Animinstance was null. If this was called during BeginPlay inside the Blueprint, please consider to add a delay before the call. - {0}"), FText::FromString(Message)));
		return false;
	}

	AnimInstance->CurrentPageIndex = InPageIndex;
	AnimInstance->bBookShouldSetKeyboardFocus = true;
	OutResult = EExecResultBookMenu::Success;
	return true;
	
}

UBookMenuAnimInstance* ABookMenuActor::GetAnimInstance() const
{
	return Cast<UBookMenuAnimInstance>(SkeletalMeshComponent->GetAnimInstance());
}

UBoxComponent* ABookMenuActor::GetLeftPageCollisionBox() const
{
	return LeftPageCollision;
}

UBoxComponent* ABookMenuActor::GetRightPageCollisionBox() const
{
	return RightPageCollision;
}

UStaticMeshComponent* ABookMenuActor::GetStaticMeshComponent() const
{
	return StaticMeshComponent;
}



#undef LOCTEXT_NAMESPACE
