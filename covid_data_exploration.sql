-- COVID-19 Data Exploration Script

USE covid_project;

-- 1: TABLE STRUCTURE EXAMINATION
-- 1.1: Check covid_cases table structure
DESCRIBE covid_cases;

-- 1.2: Check covid_vaccination table structure  
DESCRIBE covid_vaccination;

-- 2: DATA SAMPLE REVIEW
-- 2.1: View sample data from covid_cases 
SELECT * 
FROM covid_cases 
ORDER BY date ASC 
LIMIT 20;

-- 2.2: View sample data from covid_vaccination 
SELECT * 
FROM covid_vaccination 
ORDER BY date ASC 
LIMIT 20;

-- 3: BASIC DATA STATISTICS
-- 3.1: Record counts
SELECT 
    "covid_cases" as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT location) as unique_locations,
    COUNT(DISTINCT date) as unique_dates,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM covid_cases

UNION ALL

SELECT 
    "covid_vaccination" as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT location) as unique_locations,
    COUNT(DISTINCT date) as unique_dates,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM covid_vaccination;

-- 4: DATA RANGE AND DISTRIBUTION
-- 4.1: Check date ranges for both tables
SELECT 
    "covid_cases" as table_name,
    MIN(date) as min_date, 
    MAX(date) as max_date,
    COUNT(DISTINCT date) as unique_dates,
    DATEDIFF(MAX(date), MIN(date)) + 1 as expected_days,
    COUNT(DISTINCT date) / (DATEDIFF(MAX(date), MIN(date)) + 1) * 100 as date_coverage_percent
FROM covid_cases

UNION ALL

SELECT 
    "covid_vaccination" as table_name,
    MIN(date) as min_date, 
    MAX(date) as max_date,
    COUNT(DISTINCT date) as unique_dates,
    DATEDIFF(MAX(date), MIN(date)) + 1 as expected_days,
    COUNT(DISTINCT date) / (DATEDIFF(MAX(date), MIN(date)) + 1) * 100 as date_coverage_percent
FROM covid_vaccination;

-- 4.2: Check for invalid future dates (data quality issue)
SELECT 
	"covid_cases" as table_name, 
	COUNT(*) as future_dates
FROM covid_cases 
WHERE date > CURDATE()
UNION ALL
SELECT 
	"covid_vaccination" as table_name, 
	COUNT(*) as future_dates
FROM covid_vaccination 
WHERE date > CURDATE();

-- 5: LOCATION ANALYSIS
-- 5.1: Compare locations between tables
SELECT 
	"Cases only" as source, 
    location 
FROM covid_cases 
WHERE location NOT IN (SELECT DISTINCT location FROM covid_vaccination)
UNION ALL
SELECT 
	"Vaccination only" as source, 
    location 
FROM covid_vaccination 
WHERE location NOT IN (SELECT DISTINCT location FROM covid_cases);

-- 5.2: Check for location data quality issues
-- Check for leading/trailing spaces (table: covid_cases)
SELECT location
FROM covid_cases
WHERE location != TRIM(location);

-- Check for invalid values (table: covid_cases)
SELECT location
FROM covid_cases
WHERE location IN ('', 'N/A', '-', '_');

-- Check for leading/trailing spaces (table: covid_vaccination)
SELECT location
FROM covid_vaccination
WHERE location != TRIM(location);

-- Check for invalid values (table: covid_vaccination)
SELECT location
FROM covid_vaccination
WHERE location IN ('', 'N/A', '-', '_');

-- 6: CONTINENT ANALYSIS
-- 6.1: Check for continent data quality issues
-- Check for invalid values 
SELECT 
    continent,
    COUNT(*) as record_count
FROM covid_cases
WHERE continent IN ('', 'N/A', '-', '_')
GROUP BY continent;

-- Check for leading/trailing spaces
SELECT continent
FROM covid_cases
WHERE continent != TRIM (continent);

-- 7: DATA QUALITY
-- 7.1: Check for obvious data issues
SELECT 
	"new_cases" as field, 
    COUNT(*) as negative_count 
FROM covid_cases 
WHERE new_cases < 0
UNION ALL
SELECT 
	"total_cases", 
    COUNT(*)
FROM covid_cases 
WHERE total_cases < 0
UNION ALL
SELECT 
	"new_deaths", 
    COUNT(*) 
FROM covid_cases 
WHERE new_deaths < 0
UNION ALL
SELECT 
	"total_deaths", 
	COUNT(*) 
FROM covid_cases 
WHERE total_deaths < 0
UNION ALL
SELECT 
	"population", 
	COUNT(*) 
FROM covid_cases 
WHERE population < 0
UNION ALL
SELECT 
	"total_vaccinations", 
    COUNT(*) 
FROM covid_vaccination 
WHERE total_vaccinations < 0
UNION ALL
SELECT 
	"people_vaccinated", 
    COUNT(*) 
FROM covid_vaccination 
WHERE people_vaccinated < 0
UNION ALL
SELECT 
	"people_fully_vaccinated", 
    COUNT(*) 
FROM covid_vaccination 
WHERE people_fully_vaccinated < 0
UNION ALL
SELECT 
	"new_vaccinations", 
    COUNT(*) 
FROM covid_vaccination 
WHERE new_vaccinations < 0;

-- 7.2: Check for duplicate records
-- Check for duplicate records (table: covid_cases)
SELECT 
	location, 
    date, 
    COUNT(*) as duplicate_count
FROM covid_cases
GROUP BY location, date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- -- Check for duplicate records (table: covid_vaccination)
SELECT 
	location, 
    date, 
    COUNT(*) as duplicate_count
FROM covid_vaccination
GROUP BY location, date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;