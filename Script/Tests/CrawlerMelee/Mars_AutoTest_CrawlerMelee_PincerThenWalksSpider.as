// UMars_AutoTest_CrawlerMelee_PincerThenWalks on the Spider layout, playing the spider's reference pincer clip as the
// Room 5 spider wears it: after its strike the spider walks to the second target on all six legs of its wave gait.
class UMars_AutoTest_CrawlerMelee_PincerThenWalksSpider : UMars_AutoTest_CrawlerMelee_PincerThenWalks
{
    default _Origin = FVector(-300000.0, -180000.0, 600.0);
    default _LegCount = 6;
    default _Layout = EMars_Crawler_Layout::Spider;
}
