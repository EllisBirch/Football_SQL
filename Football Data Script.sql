  -- Checking the data coverage by looking at the max and min dates for each league and ordering by the leagues which have the smallest difference between the start and end date of coverage.
  -- This identified that the Europa Conference League had only been tracked for the last 14 months, the CSL for the last 15, and the NSWL Challenge Cup for the last 23. Of the other 37 leagues all
  -- have been tracked from the 2018 season to present day and so on multi-league analysis data on these 37 leagues starting at the 2018 season will be tracked. Note data on the 5 major leagues (EPL, Ligue 1, 
  -- La Liga, Bundesliga, Serie A) exists for 2016-2022. 

  SELECT MAX(date) Data_End,
  MIN(date) Data_Start,
  MAX(season) Latest_Season,
  MIN(Season) Earliest_Season,
  league,
  DATEDIFF(MONTH, MIN(date),Max(date)) Data_Len
  FROM [Football_DB].[dbo].[spi_matches$]
  GROUP BY league 
  ORDER BY DATEDIFF(MONTH, Max(date),MIN(date)) DESC;

-- Check number of fixtures each season for each team, particularly looking at covid season completeness (2019)

SELECT 2*COUNT(*) AS Season_Game_Count, -- Count(*) will calculate the number of home games each team had in a season, so assuming that most teams play the same number of home games as away, *2 for total games by each team
league,
season,
team1
FROM [Football_DB].[dbo].[spi_matches$]
WHERE score1 IS NULL
GROUP BY league, season, team1
ORDER BY league, team1, season;

-- This approach did not work as on further analysis I discovered that games with no data were still recorded, but they had a null in the score1 and score2 columns.  
-- So I tried the below. This identified that some leagues were impacted by Covid in the 2019 season, the following will all have an incomplete dataset for the 2019* season: 
-- French Ligue 1, French Ligue 2, Dutch Eredivisie, Mexican Primera Division, SPL, Belgian League, FA Women's Super League, South African ABSA Premier League, National Women's Soccer League. 
-- *2020 for National Women's Soccer League

SELECT COUNT(*) AS Total_Season_Games,
league,
season
FROM [Football_DB].[dbo].[spi_matches$]
WHERE score1 IS NULL AND score2 IS NULL 
AND season <> 2022
GROUP BY league, season
ORDER BY COUNT(*) DESC;

--Check for league and season completeness of XG data, discount leagues/seasons with NULL values from analysis-- 

SELECT COUNT(*) AS Games_No_XG,
league,
season
FROM [Football_DB].[dbo].[spi_matches$]
WHERE xg1 IS NULL AND 
xg2 IS NULL 
AND score1 IS NOT NULL -- Checking if the score is null removes fixtures where the XG data doesn't exist because the game was not played. 
AND score2 IS NOT NULL
GROUP BY league, season 
ORDER BY league, season;

--The query above showed that the Barclays Premier League, Serie A, CSL, English Championship, French Ligue 1, Bundesliga, MLS, Mexican Primera Division, Portuguese Liga, La Liga, Argentina Primera Division,
--Champions League, Europa League and Europa Conference League all had complete XG data for all games played. Hence, in XG analysis I'll focus on these leagues. (Eredivisie has XG data from 2020 onwards)

-- Comparison of home/away advantage on goals scored, depending on attribute used in the Order By clause we can also see which teams scored the highest number of goals over their XG. Comparison made at team level
-- Make comparison at league level later
DROP TABLE if exists #HomeGoalsXg
CREATE TABLE #HomeGoalsXg
(
Home_Goals float,
Home_Xg float,
league nvarchar(255),
season float,
team1 nvarchar(255),
team2 nvarchar(255)
);

INSERT INTO #HomeGoalsXg
SELECT score1 AS Home_Goals, 
CAST(xg1 AS float) AS Home_Xg, 
league,
season,
team1,
team2
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 
--'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', (cup competitions removed as due to small number of fixtures data considered unreliable)
'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND [Football_DB].[dbo].[spi_matches$].date < GETDATE() 
AND score1 IS NOT NULL
AND xg1 IS NOT NULL; -- Removes future fixtures and games not played. 

SELECT 
away.team2 Team,
away.league,
--away.season,
ROUND(AVG(CAST(home.Home_Goals AS float)),3) Avg_Home_Goals,
ROUND(AVG(CAST(home.Home_Xg AS float)),3) Avg_Home_XG, 
ROUND(AVG(CAST(home.Home_Goals AS float)) - AVG(CAST(home.Home_Xg AS float)),3) AS home_goal_xg_diff,
ROUND(AVG(CAST(away.score2 AS float)),3) Avg_Away_Goals,
ROUND(AVG(CAST(away.xg2 AS float)),3) Avg_Away_XG,
ROUND(AVG(CAST(away.score2 AS float)) - AVG(CAST(away.xg2 AS float)), 3) AS away_goal_xg_diff,
ROUND(AVG(CAST(home.Home_Goals AS float)) - AVG(CAST(home.Home_Xg AS float)),3) + ROUND(AVG(CAST(away.score2 AS float)) - AVG(CAST(away.xg2 AS float)), 3) Tot_Goal_XG_Diff,
--This metric doesn't mean much but allows us to see which team in which season scored the largest number of goals more than their XG predicted they would. 
ROUND(AVG(CAST(home.Home_goals AS float)) - AVG(CAST(away.score2 AS float)),3) Home_Away_Goal_Diff --Shows the teams with the largest difference in goal output at home/away
FROM [Football_DB].[dbo].[spi_matches$] away
INNER JOIN #HomeGoalsXg home
ON away.league = home.league
--AND away.season = home.season 
AND away.team2 = home.team1 
WHERE away.league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 
--'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', (cup competitions removed as due to small number of fixtures data considered unreliable)
'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE() -- Removes future fixtures and ensures COUNT(*) returns the actual number of games played. 
AND away.score2 IS NOT NULL
GROUP BY away.league, 
--away.season, 
away.team2
ORDER BY Home_Away_Goal_Diff DESC;

-- Comparison of goals scored by league/season, and XG by league/season broken down into home/away. The biggest home advantage in terms of win/loss was seen in the MLS, possibly due to the size of the
-- country and the distance teams have to travel for away fixtures impacting sleep etc... The smallest home advantages were all seen in the 2020 season, which was impacted by Covid and had reduced 
-- stadium capacity throughout the season, looks like fans do make a difference. 

Select 
league, 
Season,
ROUND(AVG(CAST (score1 AS float)),3) Avg_Home_Goals,
ROUND(AVG(CAST(score2 AS float)),3) Avg_Away_Goals,
ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) AS Total_Avg_Goals,
ROUND(AVG(CAST(xg1 AS float)),3) Avg_Home_XG,
ROUND(AVG(CAST(xg2 AS float)),3) Avg_Away_XG,
CAST(ROUND((SUM(CASE WHEN CAST(score1 AS float) > CAST(score2 AS float) THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) AS 'Home Win Percentage',
CAST(ROUND((SUM(CASE WHEN CAST(score2 AS float) > CAST(score1 AS float) THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) AS 'Away Win Percentage',
(CAST(ROUND((SUM(CASE WHEN CAST(score1 AS float) > CAST(score2 AS float) THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2))) - 
(CAST(ROUND((SUM(CASE WHEN CAST(score2 AS float) > CAST(score1 AS float) THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2))) AS 'Home - Away Win %',
CAST(ROUND((SUM(CASE WHEN CAST(score1 AS float) = CAST(score2 AS float) THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) AS 'Draw Percentage',
ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3) AS Total_Avg_XG,
(ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) Goal_Xg_Difference
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE() -- Removes future fixtures and ensures COUNT(*) returns the actual number of games played. 
AND score1 IS NOT NULL
GROUP BY league,season
ORDER BY 10 DESC;

-- Comparison of goals scored by league, and XG by league

Select 
league, 
ROUND(AVG(CAST (score1 AS float)),3) Avg_Home_Goals,
ROUND(AVG(CAST(score2 AS float)),3) Avg_Away_Goals,
ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) AS Total_Avg_Goals,
ROUND(AVG(CAST(xg1 AS float)),3) Avg_Home_XG,
ROUND(AVG(CAST(xg2 AS float)),3) Avg_Away_XG,
ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3) AS Total_Avg_XG,
(ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) Goal_Xg_Difference
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE() -- Removes future fixtures and ensures COUNT(*) returns the actual number of games played. 
AND score1 IS NOT NULL
GROUP BY league
ORDER BY ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) DESC;

--Check for difference between XG and actual goals scored by league/season. Data seems to show it is a good predictor, plot a scatter graph showing bell curve potentially by grouping? 

Select 
league, 
season, 
ROUND(AVG(CAST (score1 AS float)),3) Avg_Home_Goals,
ROUND(AVG(CAST(score2 AS float)),3) Avg_Away_Goals,
ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) AS Total_Avg_Goals,
ROUND(AVG(CAST(xg1 AS float)),3) Avg_Home_XG,
ROUND(AVG(CAST(xg2 AS float)),3) Avg_Away_XG,
ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3) AS Total_Avg_XG,
(ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) Goal_Xg_Difference,
CASE WHEN (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) <= -0.2 THEN '-0.2 or less'
	 WHEN (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) <= -0.1 THEN '-0.19 to -0.1'
	 WHEN (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) <= 0 THEN '-0.09 to 0'
	 WHEN (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) <= 0.1 THEN '0.01 to 0.1'
	 WHEN (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) <= 0.2 then '0.11 to 0.2'
	 WHEN (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) <= 0.3 THEN '0.21to 0.3'
	 WHEN (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) >= 0.3 THEN '0.3 or more'
	 ELSE 'Error'
END AS Goal_Xg_Grouping
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE() -- Removes future fixtures and ensures COUNT(*) returns the actual number of games played. 
AND score1 IS NOT NULL
GROUP BY league, season
ORDER BY (ROUND(AVG(CAST(score1 AS float)),3) + ROUND(AVG(CAST(score2 AS float)),3) - (ROUND(AVG(CAST(xg1 AS float)),3) + ROUND(AVG(CAST(xg2 AS float)),3))) DESC;

--Impact of introduction VAR on goals scored and XG. Premier league introduced in 2019/2022 season, Bundesliga 2017-2018, Serie A 2017-2018, La liga 2018-2019, Ligue 1 2018-2019, UCL 2019-2020. 
-- Favours away team slighty?

DROP TABLE if exists #Pre_VideoAR 
CREATE TABLE #Pre_VideoAR
(
league nvarchar(255),
Year_VAR_Introduced nvarchar(255), 
PreVAR_Home_Goals float,
PreVAR_Home_Xg float,
PreVAR_Away_Goals float,
PreVAR_Away_Xg float,
PreVAR_Tot_Goals float,
PreVAR_Tot_Xg float
);

INSERT INTO #Pre_VideoAR
SELECT 
league,
'2019-2020' Year_VAR_Introduced,
ROUND(AVG(CAST(score1 AS float)), 3) PreVAR_Home_Goals,
ROUND(AVG(CAST(xg1 AS float)), 3) PreVAR_Home_Xg,
ROUND(AVG(CAST(score2 AS float)), 3) PreVAR_Away_Goals,
ROUND(AVG(CAST(xg2 AS float)), 3) PreVAR_Away_Xg,
ROUND((AVG(CAST(score1 AS float))) + (AVG(CAST(score2 AS float))), 3) PreVAR_Tot_Goals,
ROUND((AVG(CAST(xg1 AS float))) + (AVG(CAST(xg2 AS float))), 3) PreVAR_Tot_Xg
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Barclays premier League', 'UEFA Champions League') 
AND season < 2019
GROUP BY league; 

INSERT INTO #Pre_VideoAR
SELECT league,
'2017-2018' Year_VAR_Introduced,
ROUND(AVG(CAST(score1 AS float)), 3) PreVAR_Home_Goals,
ROUND(AVG(CAST(xg1 AS float)), 3) PreVAR_Home_Xg,
ROUND(AVG(CAST(score2 AS float)), 3) PreVAR_Away_Goals,
ROUND(AVG(CAST(xg2 AS float)), 3) PreVAR_Away_Xg,
ROUND((AVG(CAST(score1 AS float))) + (AVG(CAST(score2 AS float))), 3) PreVAR_Tot_Goals,
ROUND((AVG(CAST(xg1 AS float))) + (AVG(CAST(xg2 AS float))), 3) PreVAR_Tot_Xg
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('German Bundesliga', 'Italy Serie A') 
AND season < 2018
GROUP BY league; 

INSERT INTO #Pre_VideoAR
SELECT league,
'2018-2019' Year_VAR_Introduced,
ROUND(AVG(CAST(score1 AS float)), 3) PreVAR_Home_Goals,
ROUND(AVG(CAST(xg1 AS float)), 3) PreVAR_Home_Xg,
ROUND(AVG(CAST(score2 AS float)), 3) PreVAR_Away_Goals,
ROUND(AVG(CAST(xg2 AS float)), 3) PreVAR_Away_Xg,
ROUND((AVG(CAST(score1 AS float))) + (AVG(CAST(score2 AS float))), 3) PreVAR_Tot_Goals,
ROUND((AVG(CAST(xg1 AS float))) + (AVG(CAST(xg2 AS float))), 3) PreVAR_Tot_Xg
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Spanish Primera Division', 'French Ligue 1') 
AND season < 2019
GROUP BY league; 

DROP TABLE IF EXISTS #Post_VideoAR
CREATE TABLE #Post_VideoAR
(
league nvarchar(255), 
PostVAR_Home_Goals float,
PostVAR_Home_Xg float,
PostVAR_Away_Goals float,
PostVAR_Away_Xg float,
PostVAR_Tot_Goals float,
PostVAR_Tot_Xg float
);

INSERT INTO #Post_VideoAR
SELECT 
league,
ROUND(AVG(CAST(score1 AS float)), 3) PostVAR_Home_Goals,
ROUND(AVG(CAST(xg1 AS float)), 3) PostVAR_Home_Xg,
ROUND(AVG(CAST(score2 AS float)), 3) PostVAR_Away_Goals,
ROUND(AVG(CAST(xg2 AS float)), 3) PostVAR_Away_Xg,
ROUND((AVG(CAST(score1 AS float))) + (AVG(CAST(score2 AS float))), 3) PostVAR_Tot_Goals,
ROUND((AVG(CAST(xg1 AS float))) + (AVG(CAST(xg2 AS float))), 3) PostVAR_Tot_Xg
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Barclays premier League', 'UEFA Champions League') 
AND season > 2018
AND date < GETDATE()
GROUP BY league; 

INSERT INTO #Post_VideoAR
SELECT league,
ROUND(AVG(CAST(score1 AS float)), 3) PostVAR_Home_Goals,
ROUND(AVG(CAST(xg1 AS float)), 3) PostVAR_Home_Xg,
ROUND(AVG(CAST(score2 AS float)), 3) PostVAR_Away_Goals,
ROUND(AVG(CAST(xg2 AS float)), 3) PostVAR_Away_Xg,
ROUND((AVG(CAST(score1 AS float))) + (AVG(CAST(score2 AS float))), 3) PostVAR_Tot_Goals,
ROUND((AVG(CAST(xg1 AS float))) + (AVG(CAST(xg2 AS float))), 3) PostVAR_Tot_Xg
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('German Bundesliga', 'Italy Serie A') 
AND season > 2017
AND date < GETDATE()
GROUP BY league; 

INSERT INTO #Post_VideoAR
SELECT league,
ROUND(AVG(CAST(score1 AS float)), 3) PostVAR_Home_Goals,
ROUND(AVG(CAST(xg1 AS float)), 3) PostVAR_Home_Xg,
ROUND(AVG(CAST(score2 AS float)), 3) PostVAR_Away_Goals,
ROUND(AVG(CAST(xg2 AS float)), 3) PostVAR_Away_Xg,
ROUND((AVG(CAST(score1 AS float))) + (AVG(CAST(score2 AS float))), 3) PostVAR_Tot_Goals,
ROUND((AVG(CAST(xg1 AS float))) + (AVG(CAST(xg2 AS float))), 3) PostVAR_Tot_Xg
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Spanish Primera Division', 'French Ligue 1') 
AND season > 2018
AND date < GETDATE()
GROUP BY league; 


SELECT pre.league,
Year_VAR_Introduced, 
PreVAR_Home_Goals,
PostVAR_Home_Goals,
CAST((PostVAR_Home_Goals - PreVAR_Home_Goals) AS decimal(10,2)) 'Pre/Post Home Goal Difference',
PostVAR_Home_Xg - PreVAR_Home_Xg 'Pre/Post Home Xg Difference',
PreVAR_Away_Goals,
PostVAR_Away_Goals,
PostVAR_Away_Goals - PreVAR_Away_Goals 'Pre/Post Away Goal Difference',
PostVAR_Away_Xg - PreVAR_Away_Xg 'Pre/Post Away Xg Difference',
PostVAR_Tot_Goals - PreVAR_Tot_Goals 'Pre/Post Total Goal Difference',
PostVAR_Tot_Xg - PreVAR_Tot_Xg 'Pre/Post Total Xg Difference' 
FROM #Pre_VideoAR pre
INNER JOIN #Post_VideoAR post
ON pre.league = post.league;

--most competitive league/season by average XG difference and actual goal difference

DROP TABLE IF EXISTS #GoalDifference
CREATE TABLE #GoalDifference(
league nvarchar(255),
season float,
team1 nvarchar(255),
team2 nvarchar(255),
Score_Difference float,
Xg_difference float,
)
INSERT INTO #GoalDifference
SELECT league,
season,
team1,
team2,
CASE WHEN score1 >= score2 THEN (score1 - score2)
	 WHEN score1 < score2 THEN -1 *(score1 - score2)
	 ELSE 'Error'
END AS Score_Difference,
CASE WHEN CAST(xg1 AS float) >= CAST(xg2 AS float) THEN CAST(xg1 AS float) - CAST(xg2 AS float)
	 WHEN CAST(xg1 AS float) < CAST(xg2 AS float) THEN -1 * (CAST(xg1 AS float) - CAST(xg2 AS float))
	 ELSE 'Error'
END AS Xg_difference
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE()
AND score1 IS NOT NULL 
AND xg1 IS NOT NULL

SELECT 
league,
ROUND(AVG(Score_Difference),3) 'Average Score Difference',
ROUND(AVG(Xg_difference),3) 'Average Xg Difference'
FROM #GoalDifference
GROUP BY league
ORDER BY AVG(Score_Difference) DESC;

-- How often does the team with the highest XG win. Predict that difference is likely to do with the Xg difference in games being greater in BPL games and in UCL teams taking risks due to away goal rule. 

SELECT
league,
CAST(ROUND((SUM(CASE WHEN CAST(xg1 AS float) > CAST(xg2 AS float) AND score1 > score2 THEN 1
	 WHEN CAST(xg2 AS float) > CAST(xg1 AS float) AND score2 > score1 THEN 1 
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) AS Percent_time_team_with_higher_Xg_Wins
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE()
AND score1 IS NOT NULL 
AND xg1 IS NOT NULL 
GROUP BY league
ORDER BY 2 DESC;

-- Spread of number of goals scored in each game plot as line graph showing matching trends across leagues

SELECT league,
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '0 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '1 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 2 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '2 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 3 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '3 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 4 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '4 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 5 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '5 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 6 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '6 goals scored (%)',
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 7 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '7 goals scored (%)',
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 8 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '8 goals scored (%)',
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 9 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '9 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 10 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '10+ goals scored (%)'
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE()
AND score1 IS NOT NULL
GROUP BY League;

-- Drill down to season granularity

SELECT --league,
--season,
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '0 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '1 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 2 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '2 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 3 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '3 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 4 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '4 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 5 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '5 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 6 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '6 goals scored (%)',
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 7 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '7 goals scored (%)',
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 8 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '8 goals scored (%)',
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 9 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '9 goals scored (%)', 
CAST(ROUND((SUM(CASE WHEN score1 + score2 = 10 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '10+ goals scored (%)'
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE()
AND score1 IS NOT NULL
--GROUP BY League, season;

-- Likelihood of result by league
SELECT 
--league,
CAST(ROUND((SUM(CASE WHEN score1 = 1 AND score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '1-1 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 1 AND score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '1-0 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 2 AND score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '2-1(%)',
CAST(ROUND((SUM(CASE WHEN score1 = 0 AND score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '0-0 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 0 AND score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '0-1 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 2 AND score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '2-0 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 1 AND score2 = 2 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '1-2 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 2 AND score2 = 2 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '2-2 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 0 AND score2 = 2 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '0-2 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 3 AND score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '3-0 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 3 AND score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '3-1 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 1 AND score2 = 3 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '1-3 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 3 AND score2 = 2 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '3-2 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 0 AND score2 = 3 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '0-3 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 4 AND score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '4-0 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 2 AND score2 = 3 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '2-3 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 4 AND score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '4-1 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 1 AND score2 = 4 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '1-4 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 4 AND score2 = 2 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '4-2 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 3 AND score2 = 3 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '3-3 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 0 AND score2 = 4 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '0-4 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 5 AND score2 = 0 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '5-0 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 5 AND score2 = 1 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '5-1 (%)',
CAST(ROUND((SUM(CASE WHEN score1 = 2 AND score2 = 4 THEN 1
	 ELSE 0 END) * 100.0) / COUNT(*), 2) AS decimal (10,2)) '2-4 (%)'
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE()
AND score1 IS NOT NULL
--GROUP BY League;

-- (Granularity level = season) Success rate of pre-game favourite football, compare to other sports. 
--Is football more/less predicatable? Expect less due to more draws than other sports as a result of lower scoring matches e.g. Basketball 

SELECT league, 
season,
CAST((SUM(CASE WHEN score1 > score2 AND prob1 > prob2 THEN 1 
	ELSE 0 END) + SUM(CASE WHEN score2 > score1 AND prob2 > prob1 THEN 1 
	ELSE 0 END)) * 100.0 / COUNT(*) AS decimal (10,2)) 'Pre-Game Prediction_Correct(%)'
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE()
AND score1 IS NOT NULL
and prob1 IS NOT NULL
GROUP BY league, season 
ORDER BY 1,2 DESC;

-- (Granularity level = league) Success rate of pre-game favourite football, compared to other sports. 
-- Is football more/less predicatable? Expect less due to more draws than other sports as a result of lower scoring matches e.g. Basketball.
-- We are 27.5 % better at predicting the winner of a champions league game than a championship game

SELECT league, 
CAST((SUM(CASE WHEN score1 > score2 AND prob1 > prob2 AND prob1 > probtie THEN 1 
	ELSE 0 END) + SUM(CASE WHEN score2 > score1 AND prob2 > prob1 AND prob2 > probtie THEN 1 
	ELSE 0 END) + SUM(CASE WHEN score1 = score2 AND probtie > prob1 AND probtie > prob2 THEN 1 
	ELSE 0 END)) * 100.0 / COUNT(*) AS decimal (10,2)) 'Pre-Game Prediction_Correct(%)'
FROM [Football_DB].[dbo].[spi_matches$]
WHERE league IN ('Chinese Super League', 'English League Championship', 'French Ligue 1', 'Italy Serie A', 'Major League Soccer', 'Mexican Primera Division Torneo Apertura', 
'Portuguese Liga', 'Spanish Primera Division', 'UEFA Champions League', 'UEFA Europa Conference League', 'UEFA Europa League', 'Barclays Premier League', 'German Bundesliga', 'Argentina Primera Division')
AND date < GETDATE()
AND score1 IS NOT NULL
and prob1 IS NOT NULL
GROUP BY league
ORDER BY 2 DESC;

