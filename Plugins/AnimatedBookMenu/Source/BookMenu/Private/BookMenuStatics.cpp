// Copyright 2024 Suricoon. All Rights Reserved.

#include "BookMenuStatics.h"
#include "Actors/BookMenuActor.h"
#include "Blueprint/UserWidget.h"
#include "Components/WidgetComponent.h"
#include "Components/WidgetInteractionComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Kismet/KismetMathLibrary.h"
#include "Slate/WidgetRenderer.h"
#include "Components/BoxComponent.h"
#include "DataAssets/BookMenuData.h"

#define LOCTEXT_NAMESPACE "BookMenuPlugin"

void UBookMenuStatics::DrawUserWidgetToRenderTarget2D(UUserWidget* UserWidget, UTextureRenderTarget2D* RenderTarget,
                                                      const FVector2D DrawSize, const float DeltaTime, const bool bUseGammaCorrection)
{
	if(UserWidget == nullptr || RenderTarget == nullptr)
	{
		return;
	}	

	FWidgetRenderer * WidgetRenderer = new FWidgetRenderer(bUseGammaCorrection);
	const TSharedRef<SWidget> Widget = UserWidget->TakeWidget();
	WidgetRenderer->DrawWidget(RenderTarget, Widget, DrawSize, DeltaTime);
	BeginCleanup(WidgetRenderer);
	
}

UTextureRenderTarget2D* UBookMenuStatics::CreateTextureRenderTarget2D(const FVector2D DrawSize, const TextureFilter TextureFilter,
                                                                      const bool UseGammaCorrection)
{
	return FWidgetRenderer::CreateTargetFor(DrawSize, TextureFilter, UseGammaCorrection);
}

APlayerController* UBookMenuStatics::GetLocalPlayerController(const UObject* WorldContextObject)
{
	if (WorldContextObject == nullptr || WorldContextObject->GetWorld() == nullptr)
	{
		return nullptr;
	}

	const ULocalPlayer * Player = WorldContextObject->GetWorld()->GetFirstLocalPlayerFromController();

	if(Player == nullptr)
	{
		return nullptr;
	}

	return Player->GetPlayerController(WorldContextObject->GetWorld());
}

bool UBookMenuStatics::BookUvTrace(const UObject* WorldContextObject, ABookMenuActor* BookMenuActor, FVector Start, FVector End,
                                   FVector2D& OutUVCoordinates, int32& OutPageIndex, bool bDebugTrace, ECollisionChannel TraceChannel)
{

	OutUVCoordinates = FVector2D();
	OutPageIndex = -1;
	
	if (WorldContextObject == nullptr || WorldContextObject->GetWorld() == nullptr)
	{
		return false;
	}
	
	TArray<FHitResult> HitResults;
	FCollisionQueryParams Params = FCollisionQueryParams();
	Params.bTraceComplex = true;
	Params.bReturnPhysicalMaterial = true;
	Params.bReturnFaceIndex = true;

#if !(UE_BUILD_SHIPPING || UE_BUILD_TEST)

	if(bDebugTrace)
	{
		const FName TraceTag("WidgetInteractionTraceTag");
		WorldContextObject->GetWorld()->DebugDrawTraceTag = TraceTag;
		Params.TraceTag = TraceTag;
	}

#endif
	
	if(!WorldContextObject->GetWorld()->LineTraceMultiByChannel(HitResults, Start, End, TraceChannel, Params))
	{
		return false;
	}

	bool bPageCollisionFound = false;
	bool bMeshCollisionFound = false;
	bool bIsLeftPage = false;
	
	FHitResult MeshHit;
	
	for(auto hit : HitResults)
	{
		if(hit.GetComponent() == BookMenuActor->GetStaticMeshComponent())
		{
			bMeshCollisionFound = true;
			MeshHit = hit;
			continue;
		}	
		
		if(!bMeshCollisionFound)
		{
			if(hit.GetComponent() == BookMenuActor->GetLeftPageCollisionBox())
			{
				bIsLeftPage = true;
				bPageCollisionFound = true;
			}
			else if(hit.GetComponent() == BookMenuActor->GetRightPageCollisionBox())
			{
				bIsLeftPage = false;
				bPageCollisionFound = true;
			}
		}
	}

	if(bMeshCollisionFound == false || bPageCollisionFound == false)
	{
		return false;
	}

	if(bIsLeftPage)
	{
		OutPageIndex = 0;
	}
	else
	{
		OutPageIndex = 1;
	}

	if(FVector2D UVCoordinates; UGameplayStatics::FindCollisionUV(MeshHit,0,UVCoordinates))
	{
		OutUVCoordinates = UVCoordinates;
		return true;
	}

	return false;
}

bool UBookMenuStatics::MoveWidgetInteractionPointer(UWidgetInteractionComponent* InWidgetInteractionComponent,
                                                    UWidgetComponent* InWidgetComponent, const FRotator InReferenceRotation,
                                                    const FVector2D UVCoordinates, const bool bDebugTrace)
{
	if(InWidgetInteractionComponent == nullptr || InWidgetComponent == nullptr)
	{
		return false;
	}

	if(InWidgetComponent->GetComponentScale().X != InWidgetComponent->GetComponentScale().Y)
	{
		//Non uniform scale of widget component
		return false;
	}

	const FVector2D DrawSize = InWidgetComponent->GetDrawSize();
	const float ScaleFactor = InWidgetComponent->GetComponentScale().X;

	const float ScaledX = (UVCoordinates.X - 0.5f) * (DrawSize.X * ScaleFactor);
	const float ScaledY = (0.5f - UVCoordinates.Y) * (DrawSize.Y * ScaleFactor);

	const FRotator Rotation = InReferenceRotation;
	const FVector Target = UKismetMathLibrary::GetUpVector(Rotation) * ScaledY +
						UKismetMathLibrary::GetRightVector(Rotation) * ScaledX +
							InWidgetComponent->GetComponentLocation();

	const FVector Start = InWidgetInteractionComponent->GetComponentLocation();
	const FRotator TargetRotation = UKismetMathLibrary::FindLookAtRotation(Start, Target);

		if(InWidgetInteractionComponent->InteractionSource != EWidgetInteractionSource::World)
	{
		InWidgetInteractionComponent->InteractionSource = EWidgetInteractionSource::World;
	}

	InWidgetInteractionComponent->bShowDebug = bDebugTrace;
	InWidgetInteractionComponent->SetWorldRotation(TargetRotation);

	return true;
	
}

bool UBookMenuStatics::ResetWidgetInteractionPointer(UWidgetInteractionComponent* InWidgetInteractionComponent,
	FVector InZeroLocation, FRotator InReferenceRotation, bool bDebugTrace)
{
	if(InWidgetInteractionComponent == nullptr)
	{
		return false;
	}

	const FRotator Rotation = InReferenceRotation;
	const FVector Target = UKismetMathLibrary::GetUpVector(Rotation) +
						UKismetMathLibrary::GetRightVector(Rotation) +
							InZeroLocation;

	const FVector Start = InWidgetInteractionComponent->GetComponentLocation();
	const FRotator TargetRotation = UKismetMathLibrary::FindLookAtRotation(Start, Target);

	if(InWidgetInteractionComponent->InteractionSource != EWidgetInteractionSource::World)
	{
		InWidgetInteractionComponent->InteractionSource = EWidgetInteractionSource::World;
	}

	InWidgetInteractionComponent->bShowDebug = bDebugTrace;
	InWidgetInteractionComponent->SetWorldRotation(TargetRotation);

	return true;
}

bool UBookMenuStatics::CreateMouseTraceParameters(APlayerController* PlayerController, const float TraceDistance,
                                                  FVector& OutStart, FVector& OutEnd, EExecResultBookMenu& OutResult)
{
	OutStart = FVector();
	OutEnd = FVector();
	OutResult = EExecResultBookMenu::Failed;
	
	if(PlayerController == nullptr || TraceDistance == 0.f)
	{
		return false;
	}

	FVector worldLocation;
	FVector worldDirection;
	
	if(!PlayerController->DeprojectMousePositionToWorld(worldLocation, worldDirection))
	{
		return false;
	}

	OutStart = worldLocation;
	OutEnd = worldDirection * TraceDistance + worldLocation;
	OutResult = EExecResultBookMenu::Success;
	return true;
}

UBookMenuData* UBookMenuStatics::CreateBookMenuDataRuntimeInstance(UObject* Outer, UBookMenuData* Template,
	EExecResultBookMenu& OutResult)
{
	if(Outer == nullptr || Template == nullptr)
	{
		OutResult = EExecResultBookMenu::Failed;
		return nullptr;
	}
	
	//Duplicate this object and set the new outer
	FObjectDuplicationParameters param = FObjectDuplicationParameters(Template, Outer);
	param.DestClass = Template->GetClass();
	UBookMenuData * clone = Cast<UBookMenuData>(StaticDuplicateObjectEx(param));
	clone->bIsRuntimeCreated = true;
	return clone;
	
}



#undef LOCTEXT_NAMESPACE
