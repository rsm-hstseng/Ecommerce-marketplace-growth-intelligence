-- CHECK 1: Number of opportunities per scenario

SELECT
    scenario,
    COUNT(*) AS opportunity_count,
    MIN(opportunity_score) AS min_score,
    MAX(opportunity_score) AS max_score
FROM marts.mart_weight_sensitivity
GROUP BY scenario
ORDER BY scenario;

-- CHECK 2: Baseline rankings must match Step 9

SELECT
    COUNT(*) AS mismatched_baseline_ranks
FROM marts.mart_weight_sensitivity
WHERE scenario = 'Baseline'
  AND baseline_rank <> scenario_rank;

-- CHECK 3: Compare Top 10 Across Scenarios

SELECT
    scenario,
    scenario_rank,
    category_name,
    customer_state,
    baseline_rank,
    rank_improvement,
    opportunity_score
FROM marts.mart_weight_sensitivity
WHERE scenario_rank <= 10
ORDER BY scenario, scenario_rank;

-- CHECK 4: Top 10 Overlap with Baseline

SELECT
    scenario,
    COUNT(*) AS top_10_overlap
FROM marts.mart_weight_sensitivity
WHERE scenario_rank <= 10
  AND baseline_rank <= 10
GROUP BY scenario
ORDER BY scenario;

-- CHECK 5: Validate Scenario Scores

SELECT
    COUNT(*) AS invalid_scores
FROM marts.mart_weight_sensitivity
WHERE opportunity_score IS NULL
   OR opportunity_score < 0
   OR opportunity_score > 100;
