// Copyright 2024 Suricoon. All Rights Reserved.

#include "Actors/BookMenuInteractionActor.h"
#include "BookMenuStatics.h"
#include "Components/WidgetComponent.h"
#include "Components/WidgetInteractionComponent.h"


// Sets default values
ABookMenuInteractionActor::ABookMenuInteractionActor(): DefaultSceneRoot(nullptr), WidgetInteractionComponent(nullptr),
                                                        PageWidgetComponentA(nullptr)
{
	// Set this actor to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = true;

	const FAttachmentTransformRules AttachmentRules = FAttachmentTransformRules(EAttachmentRule::KeepRelative, false);

	DefaultSceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("DefaultSceneRoot"));
	RootComponent = DefaultSceneRoot;
	
	WidgetInteractionComponent = CreateDefaultSubobject<UWidgetInteractionComponent>(TEXT("PageWidgetInteractionComponent"));
	WidgetInteractionComponent->AttachToComponent(RootComponent, AttachmentRules);
	WidgetInteractionComponent->SetRelativeLocation(FVector(0.f,0.f,0.f));

	PointerZero = CreateDefaultSubobject<UArrowComponent>(TEXT("PointerZeroComponent"));
	PointerZero->AttachToComponent(RootComponent, AttachmentRules);
	PointerZero->SetRelativeLocation(FVector(0.f,0.f,300.f));

	DrawSize = FVector2D(2048,2048);
	
	PageWidgetComponentA = CreateDefaultSubobject<UWidgetComponent>(TEXT("PageWidgetComponentA"));
	PageWidgetComponentA->AttachToComponent(RootComponent, AttachmentRules);
	PageWidgetComponentA->SetRelativeRotation(FRotator(0.f,180.f,0.f));
	PageWidgetComponentA->SetRelativeLocation(FVector(100.f , -100.f, 0.f));
	PageWidgetComponentA->SetRelativeScale3D(FVector(0.1f, 0.1f, 0.1f));
	PageWidgetComponentA->SetDrawSize(DrawSize);
	PageWidgetComponentA->SetTickWhenOffscreen(true);

	PageWidgetComponentB = CreateDefaultSubobject<UWidgetComponent>(TEXT("PageWidgetComponentB"));
	PageWidgetComponentB->AttachToComponent(RootComponent, AttachmentRules);
	PageWidgetComponentB->SetRelativeRotation(FRotator(0.f,180.f,0.f));
	PageWidgetComponentB->SetRelativeLocation(FVector(100.f , 100.f, 0.f));
	PageWidgetComponentB->SetRelativeScale3D(FVector(0.1f, 0.1f, 0.1f));
	PageWidgetComponentB->SetDrawSize(DrawSize);
	PageWidgetComponentB->SetTickWhenOffscreen(true);

	PageWidgetComponentC = CreateDefaultSubobject<UWidgetComponent>(TEXT("PageWidgetComponentC"));
	PageWidgetComponentC->AttachToComponent(RootComponent, AttachmentRules);
	PageWidgetComponentC->SetRelativeRotation(FRotator(0.f,0.f,0.f));
	PageWidgetComponentC->SetRelativeLocation(FVector(110.f , -100.f, 0.f));
	PageWidgetComponentC->SetRelativeScale3D(FVector(0.1f, 0.1f, 0.1f));
	PageWidgetComponentC->SetDrawSize(DrawSize);
	PageWidgetComponentC->SetTickWhenOffscreen(true);

	PageWidgetComponentD = CreateDefaultSubobject<UWidgetComponent>(TEXT("PageWidgetComponentD"));
	PageWidgetComponentD->AttachToComponent(RootComponent, AttachmentRules);
	PageWidgetComponentD->SetRelativeRotation(FRotator(0.f,0.f,0.f));
	PageWidgetComponentD->SetRelativeLocation(FVector(110.f , 100.f, 0.f));
	PageWidgetComponentD->SetRelativeScale3D(FVector(0.1f, 0.1f, 0.1f));
	PageWidgetComponentD->SetDrawSize(DrawSize);
	PageWidgetComponentD->SetTickWhenOffscreen(true);
	
	WidgetInteractionComponent->bEnableHitTesting = true;
	WidgetInteractionComponent->TraceChannel = ECC_Visibility;
	WidgetInteractionComponent->InteractionDistance = 500.f;
	
}

// Called when the game starts or when spawned
void ABookMenuInteractionActor::BeginPlay()
{
	Super::BeginPlay();
}

// Called every frame
void ABookMenuInteractionActor::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
}

bool ABookMenuInteractionActor::MovePointer(const FVector2D UVCoordinates, const bool bDebugTrace)
{
	if(ActiveWidgetComponent == nullptr)
	{
		return ResetPointer(bDebugTrace);
	}
	
	return UBookMenuStatics::MoveWidgetInteractionPointer(WidgetInteractionComponent, ActiveWidgetComponent, GetActorRotation(), UVCoordinates, bDebugTrace);
}

bool ABookMenuInteractionActor::ResetPointer(bool bDebugTrace)
{
	return UBookMenuStatics::ResetWidgetInteractionPointer(WidgetInteractionComponent, PointerZero->GetComponentLocation(), GetActorRotation(), bDebugTrace);
}

UWidgetInteractionComponent* ABookMenuInteractionActor::GetInteractionComponent() const
{
	return WidgetInteractionComponent;
}


