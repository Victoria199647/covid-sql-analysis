# COVID-19 SQL Analysis Project

This project uses MySQL to conduct in-depth analysis of global COVID-19 data sourced from [Our World in Data](https://ourworldindata.org/coronavirus).  
The project demonstrates advanced SQL techniques including window functions, subqueries, CTEs, data classification, and mortality analysis.

---

## Current Files

- `covid_analysis.sql`  
  Core SQL analysis including:
  - Weekly surge detection in COVID-19 cases
  - Vaccination vs. mortality classification by country (2021)
  - Peak infection periods by continent using `RANK()`
  - Pre- vs. post-vaccination mortality comparison

---

## Key Analyses in `covid_analysis.sql`

### 1. Weekly Rise in Cases
- Calculates 7-day rolling totals and identifies countries with the steepest weekly rise.
- Uses `LAG()` and `SUM OVER()` functions.

### 2. Mortality vs. Vaccination Categories (2021)
- Categorizes countries into:
  - **Mortality:** High (>5%) or Normal (≤5%)
  - **Vaccination coverage:** Low, Medium, or High
- Enables public health segmentation based on case severity and immunization.

### 3. Peak Period Ranking by Continent
- Uses `RANK()` and `DENSE_RANK()` to find top 3 daily peaks in each continent.

### 4. Vaccine Effectiveness Evaluation
- Compares mortality rates **before** vs **after** vaccination rollout (with a 60-day lag buffer).
- Applies subqueries and `EXISTS` to filter countries with:
  - Enough pre/post-vaccine data (≥30 days, ≥1000/500 cases)
  - Population ≥1 million
- Outputs mortality rate change percentage and classification: Improved / Worsened / No Change.

---

## SQL Features Used

- `CREATE VIEW`
- `WINDOW FUNCTIONS`: `LAG()`, `RANK()`, `DENSE_RANK()`, `SUM OVER`
- `CTEs`
- `CASE WHEN` classification logic
- `JOIN`, `GROUP BY`, `HAVING`
- Subqueries, correlated subqueries, `EXISTS`
- `NULLIF`, `ROUND`, and aggregation functions

---

## Data Source

- [Our World in Data COVID-19 Dataset](https://ourworldindata.org/covid-cases)

## Tools Used

- **Database:** MySQL 
- **Data Source:** OWID COVID-19  
- **Platform:** GitHub (for version control and project structure)
