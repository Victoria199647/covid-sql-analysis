USE covid_project;

# Create view: valid_countries_cases
CREATE OR REPLACE VIEW valid_countries_cases AS
SELECT *
FROM covid_cases
WHERE continent IS NOT NULL;

-- SELECT COUNT(*) FROM valid_countries_cases;

# Create view: valid_countries_vaccination
CREATE OR REPLACE VIEW valid_countries_vaccination AS
SELECT *
FROM covid_vaccination
WHERE location NOT IN ('Africa', 'world', 'Asia', 'Europe', 'North America', 'South America', 'Oceania')
 AND location NOT LIKE '%27%'
 AND location NOT LIKE '%income%';
 
-- SELECT COUNT(*) FROM valid_countries_vaccination;

# Top 10 countries with steepest weekly rise in cases
WITH weekly_cases AS (
  SELECT 
    location,
    date,
    SUM(new_cases) OVER (
      PARTITION BY location
      ORDER BY date
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7_day_cases
  FROM valid_countries_cases
),
weekly_diff AS (
  SELECT 
    location,
    date,
    rolling_7_day_cases,
    LAG(rolling_7_day_cases, 7) OVER (PARTITION BY location ORDER BY date) AS prev_week_cases
  FROM weekly_cases
),
latest_data AS (
  SELECT 
    location,
    MAX(date) AS latest_date
  FROM weekly_diff
  GROUP BY location
)
SELECT 
  wd.location,
  wd.date,
  (wd.rolling_7_day_cases - wd.prev_week_cases) AS weekly_rise
FROM weekly_diff wd
JOIN latest_data ld ON wd.location = ld.location AND wd.date = ld.latest_date
WHERE wd.prev_week_cases IS NOT NULL
ORDER BY weekly_rise DESC
LIMIT 10;

# Global Analysis: COVID-19 Mortality Rates vs Vaccination Coverage by Country Classification (2021)
-- Mortality rate categories: High (>5%), Normal (≤5%)
-- Vaccination coverage categories: Low/Medium/High
WITH combined_data AS (
	SELECT
		c.location,
        c.continent,
        c.date,
        c.new_cases,
        c.new_deaths,
        c.population,
        v.new_vaccinations
	FROM valid_countries_cases c
    LEFT JOIN valid_countries_vaccination v
		ON c.location = v.location AND c.date = v.date
),
data_2021 AS (
	SELECT *
    FROM combined_data
    WHERE YEAR(date) = 2021
    AND population IS NOT NULL
    AND population > 0
),
country_analysis AS (
	SELECT
		location,
        continent,
        MAX(population) AS population,
        SUM(new_vaccinations) AS total_vaccinated,
        SUM(new_cases) AS total_cases,
        SUM(new_deaths) AS total_deaths
	FROM data_2021
    GROUP BY location, continent
    HAVING SUM(new_vaccinations) > 0
		AND SUM(new_cases) > 0
        AND SUM(new_deaths) > 0
)
SELECT
	location,
    continent,
    CASE
		WHEN ROUND((total_deaths * 100.0 / NULLIF(total_cases, 0)), 2) > 5
        THEN 'High Mortality'
        ELSE 'Normal Mortality'
        END AS mortality_category,
	CASE
		WHEN ROUND((total_vaccinated * 100.0 / NULLIF(population, 0)), 2) < 30
        THEN 'Low Vaccination Rate'
        WHEN ROUND((total_vaccinated * 100.0 / NULLIF(population, 0)), 2) < 70
        THEN 'Medium Vaccination Rate'
        ELSE 'High Vaccination Rate'
	END AS vaccination_category
FROM country_analysis
ORDER BY 
    mortality_category DESC,
    vaccination_category ASC,
    location;
    
# Ranking COVID-19 Peak Periods by Continent Using RANK() Function
WITH daily_continent_cases AS (
    SELECT 
        continent,
        date,
        COALESCE(SUM(new_cases), 0) as daily_cases,
        RANK() OVER (PARTITION BY continent ORDER BY COALESCE(SUM(new_cases), 0) DESC) as case_rank,
        DENSE_RANK() OVER (PARTITION BY continent ORDER BY COALESCE(SUM(new_cases), 0) DESC) as case_dense_rank
    FROM valid_countries_cases
    WHERE continent IS NOT NULL
    GROUP BY continent, date
)
SELECT 
    continent,
    date,
    daily_cases,
    case_rank
FROM daily_continent_cases
WHERE case_dense_rank <= 3
ORDER BY continent, case_rank;

# Vaccine Effectiveness Analysis Using Subqueries and EXISTS
-- Find the start date of vaccination for each country
WITH country_vaccine_start AS (
    SELECT 
        location,
        MIN(date) as vaccine_start_date
    FROM valid_countries_vaccination 
    WHERE new_vaccinations > 0 
       OR people_vaccinated > 0 
       OR total_vaccinations > 0
    GROUP BY location
),

-- Get basic information for each country
country_basic_info AS (
    SELECT DISTINCT 
        location, 
        population
    FROM valid_countries_cases 
    WHERE population IS NOT NULL AND population > 0
),

mortality_comparison AS (
    SELECT 
        cbi.location,
        cbi.population,
        cvs.vaccine_start_date,
		-- Overall mortality rate before vaccination
        (SELECT 
            CASE 
                WHEN SUM(new_cases) > 0 THEN ROUND((SUM(new_deaths) * 100.0 / SUM(new_cases)), 4)
                ELSE NULL 
            END
         FROM valid_countries_cases pre
         WHERE pre.location = cbi.location 
         AND pre.date < cvs.vaccine_start_date
         AND pre.new_cases > 0 
         AND pre.new_deaths >= 0
        ) as mortality_rate_before_vaccine,
        -- Overall mortality rate after vaccination (starting 60 days post-vaccination)
        (SELECT 
            CASE 
                WHEN SUM(new_cases) > 0 THEN ROUND((SUM(new_deaths) * 100.0 / SUM(new_cases)), 4)
                ELSE NULL 
            END
         FROM valid_countries_cases post
         WHERE post.location = cbi.location 
         AND post.date >= DATE_ADD(cvs.vaccine_start_date, INTERVAL 60 DAY)
         AND post.new_cases > 0 
         AND post.new_deaths >= 0
        ) as mortality_rate_after_vaccine,
        -- Final vaccination coverage rate
        (SELECT ROUND(MAX(people_fully_vaccinated * 100.0 / cbi.population), 2)
         FROM valid_countries_vaccination v
         WHERE v.location = cbi.location 
         AND v.people_fully_vaccinated IS NOT NULL
        ) as final_vaccination_pct
        
    FROM country_basic_info cbi
    JOIN country_vaccine_start cvs 
		ON cbi.location = cvs.location
    
    -- Ensure sufficient data before vaccination
    WHERE EXISTS (
        SELECT 1 
        FROM valid_countries_cases c1
        WHERE c1.location = cbi.location
        AND c1.date < cvs.vaccine_start_date
        AND c1.new_cases > 0
        GROUP BY c1.location
        HAVING COUNT(*) >= 30  -- At least 30 days of data before vaccination
           AND SUM(c1.new_cases) >= 1000  -- At least 1000 cases
    )
    
    -- Ensure sufficient data after vaccination
    AND EXISTS (
        SELECT 1
        FROM valid_countries_cases c2
        WHERE c2.location = cbi.location
        AND c2.date >= DATE_ADD(cvs.vaccine_start_date, INTERVAL 60 DAY)
        AND c2.new_cases > 0
        GROUP BY c2.location
        HAVING COUNT(*) >= 30  -- At least 30 days of data after vaccination
           AND SUM(c2.new_cases) >= 500   -- At least 500 cases
    )
    
    -- Exclude countries with small populations
    AND cbi.population >= 1000000
)

-- Main results: Pre vs Post vaccination mortality rate comparison
SELECT 
    location,
    population,
    vaccine_start_date,
    -- Mortality rate comparison
    mortality_rate_before_vaccine as death_rate_before_pct,
    mortality_rate_after_vaccine as death_rate_after_pct,
    final_vaccination_pct,
    -- Mortality rate change analysis
    ROUND((mortality_rate_after_vaccine - mortality_rate_before_vaccine), 4) as death_rate_change,
    ROUND(((mortality_rate_after_vaccine - mortality_rate_before_vaccine) * 100.0 / mortality_rate_before_vaccine), 2) as death_rate_change_percentage,
    
    CASE 
        WHEN mortality_rate_after_vaccine < mortality_rate_before_vaccine THEN 'Improved'
        WHEN mortality_rate_after_vaccine > mortality_rate_before_vaccine THEN 'Worsened'
        ELSE 'No Change'
    END as mortality_trend

FROM mortality_comparison

-- Filter countries with complete data
WHERE mortality_rate_before_vaccine IS NOT NULL 
  AND mortality_rate_after_vaccine IS NOT NULL

-- Order by mortality rate improvement (most improved first)
ORDER BY (mortality_rate_before_vaccine - mortality_rate_after_vaccine) DESC;