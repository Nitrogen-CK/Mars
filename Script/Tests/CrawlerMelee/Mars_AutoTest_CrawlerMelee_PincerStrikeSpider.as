// UMars_AutoTest_CrawlerMelee_PincerStrike on the Spider layout (the rig measured from the spider model, at its size and
// clearance, on its own gait), playing the spider's reference pincer clip as the Room 5 spider wears it: its claw keys are
// posed by its first and last leg, the body rears by the windup key's pitch, and the jab still lands once.
class UMars_AutoTest_CrawlerMelee_PincerStrikeSpider : UMars_AutoTest_CrawlerMelee_PincerStrike
{
    default _Origin = FVector(-290000.0, -180000.0, 600.0);
    default _LegCount = 6;
    default _Layout = EMars_Crawler_Layout::Spider;
    // The spider gait's step threshold is 50 cm, and an emergency step is 1.75 of it.
    default _ReplantStep = 90.0;
}
