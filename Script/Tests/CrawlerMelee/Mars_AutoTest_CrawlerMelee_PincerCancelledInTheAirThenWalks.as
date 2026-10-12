// UMars_AutoTest_CrawlerMelee_PincerThenWalks with the first attack cancelled as it enters Strike, both claws in the air
// at the windup key, by a cancel that skips the eased recovery (aggression switched off). The gait has to take both legs
// back from the air before the crawler can walk to the second target.
class UMars_AutoTest_CrawlerMelee_PincerCancelledInTheAirThenWalks : UMars_AutoTest_CrawlerMelee_PincerThenWalks
{
    default _Origin = FVector(-280000.0, -180000.0, 600.0);
    default _CancelFirstAttackMidAir = true;
}
