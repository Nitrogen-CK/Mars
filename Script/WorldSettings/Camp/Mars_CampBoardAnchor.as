class AMars_CampBoardAnchor : AActor
{
    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(EditAnywhere, Category = "Camp Board")
    EMars_CampStation Station = EMars_CampStation::Title;

    UPROPERTY(EditAnywhere, Category = "Camp Board")
    FIntPoint DrawSize = FIntPoint(700, 900);
}
