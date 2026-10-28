import pandas as pd
import plotly.express as px
import streamlit as st
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from pathlib import Path
from ui_components import render_header, render_insight, render_footer

# ==========================================
# PAGE CONFIGURATION
# ==========================================

st.set_page_config(
    page_title="Opportunity Explorer",
    page_icon="🎯",
    layout="wide",
)
# Load shared dashboard styling
css_file = Path(__file__).resolve().parents[1] / "style.css"

st.markdown(
    f"<style>{css_file.read_text(encoding='utf-8')}</style>",
    unsafe_allow_html=True,
)
# PLOTLY THEME
px.defaults.template = "plotly_white"
px.defaults.color_discrete_sequence = [
    "#0F766E",
    "#2563EB",
    "#D97757",
    "#7C3AED",
    "#64748B",
]

render_header(
    "Strategic Opportunity Explorer",
    "Explainable Category × Region Prioritization | 2018 Q1 vs Q2",
)


# ==========================================
# POSTGRESQL CONNECTION
# ==========================================


@st.cache_resource
def get_engine():
    db = st.secrets["postgres"]

    url = URL.create(
        "postgresql+psycopg",
        username=db["user"],
        password=db["password"],
        host=db["host"],
        port=db["port"],
        database=db["database"],
    )

    return create_engine(url, pool_pre_ping=True)


@st.cache_data(ttl=600)
def load_data(sql):
    with get_engine().connect() as conn:
        return pd.read_sql_query(text(sql), conn)


# ==========================================
# LOAD PRECOMPUTED ANALYTICS
# ==========================================

try:
    sensitivity = load_data("""
        SELECT *
        FROM marts.mart_weight_sensitivity
    """)

    components = load_data("""
        SELECT
            category_name,
            customer_state,
            growth_score,
            scale_score,
            diversification_score,
            delivery_score
        FROM marts.mv_opportunity_scores
    """)

except Exception as e:
    st.error("Unable to load opportunity analytics.")
    st.exception(e)
    st.stop()


if sensitivity.empty:
    st.warning("No eligible opportunities found.")
    st.stop()


# ==========================================
# DATA TYPES
# ==========================================

numeric_cols = [
    "baseline_rank",
    "scenario_rank",
    "rank_improvement",
    "opportunity_score",
    "q1_gmv",
    "q2_gmv",
    "growth_pct",
    "q2_orders",
    "q2_active_sellers",
    "hhi",
    "on_time_delivery_pct",
    "growth_weight",
    "scale_weight",
    "diversification_weight",
    "delivery_weight",
]

for col in numeric_cols:
    sensitivity[col] = pd.to_numeric(sensitivity[col], errors="coerce")

score_cols = [
    "growth_score",
    "scale_score",
    "diversification_score",
    "delivery_score",
]

for col in score_cols:
    components[col] = pd.to_numeric(components[col], errors="coerce")

# Ensure one record per opportunity and scenario.
data = sensitivity.merge(
    components,
    on=["category_name", "customer_state"],
    how="left",
    validate="many_to_one",
)


# ==========================================
# SIDEBAR FILTERS
# ==========================================

st.sidebar.header("Opportunity Filters")

scenario_order = [
    "Baseline",
    "Growth-focused",
    "Balanced",
    "Delivery-focused",
]

available_scenarios = [s for s in scenario_order if s in data["scenario"].unique()]

selected_scenario = st.sidebar.selectbox(
    "Business Strategy",
    available_scenarios,
)

scenario_data = data[data["scenario"] == selected_scenario].copy()

states = sorted(scenario_data["customer_state"].dropna().unique())

selected_state = st.sidebar.selectbox(
    "Customer Region",
    ["All Regions"] + states,
)

minimum_gmv = st.sidebar.number_input(
    "Minimum Q2 GMV (BRL)",
    min_value=0,
    value=0,
    step=5000,
)

filtered = scenario_data.copy()

if selected_state != "All Regions":
    filtered = filtered[filtered["customer_state"] == selected_state]

filtered = filtered[filtered["q2_gmv"] >= minimum_gmv].sort_values("scenario_rank")

# Rankings are global. Filters do not recalculate them.


# ==========================================
# SCENARIO OVERVIEW
# ==========================================

st.header("1. Strategy & Opportunity Overview")

if filtered.empty:
    st.warning("No opportunities match your filters.")
    st.stop()

# ==========================================
# BUSINESS INSIGHT
# ==========================================

best = filtered.sort_values("scenario_rank").iloc[0]

render_insight(
    "Top Opportunity in Current View",
    (
        f"{best['category_name']} in "
        f"{best['customer_state']} is the highest-ranked "
        f"opportunity matching the current filters, "
        f"with a score of "
        f"{best['opportunity_score']:.2f}/100. "
        "Rankings reflect the selected business weights, "
        "not predicted financial returns."
    ),
)


weights = scenario_data.iloc[0]

st.info(
    f"Current strategy: {selected_scenario} | "
    f"Growth {weights['growth_weight']:.0%} · "
    f"Scale {weights['scale_weight']:.0%} · "
    f"Diversification "
    f"{weights['diversification_weight']:.0%} · "
    f"Delivery {weights['delivery_weight']:.0%}"
)

baseline_top10 = set(
    data.loc[
        (data["scenario"] == "Baseline") & (data["scenario_rank"] <= 10),
        ["category_name", "customer_state"],
    ].itertuples(index=False, name=None)
)

current_top10 = set(
    scenario_data.loc[
        scenario_data["scenario_rank"] <= 10,
        ["category_name", "customer_state"],
    ].itertuples(index=False, name=None)
)

overlap = len(baseline_top10 & current_top10)

k1, k2, k3, k4 = st.columns(4)

with k1:
    st.metric(
        "Matching Opportunities",
        f"{len(filtered):,}",
    )

with k2:
    st.metric(
        "Highest Global Rank in Filter",
        f"#{int(filtered['scenario_rank'].min())}",
    )

with k3:
    st.metric(
        "Highest Score in Filter",
        f"{filtered['opportunity_score'].max():.2f}",
    )

with k4:
    st.metric(
        "Global Top 10 Overlap",
        f"{overlap}/10",
    )

st.caption(
    "The region and GMV filters affect the displayed "
    "opportunities, not the global scenario rankings "
    "or global Top 10 overlap."
)


# ==========================================
# TOP OPPORTUNITIES
# ==========================================

st.header("2. Top Ranked Opportunities")

top = filtered.head(15).copy()

top["opportunity_label"] = top["category_name"] + " | " + top["customer_state"]

fig_ranking = px.bar(
    top.sort_values("opportunity_score"),
    x="opportunity_score",
    y="opportunity_label",
    orientation="h",
    color="growth_pct",
    color_continuous_scale="Blues",
    hover_data=[
        "scenario_rank",
        "q2_gmv",
        "q2_orders",
        "hhi",
        "on_time_delivery_pct",
    ],
    labels={
        "opportunity_score": "Opportunity Score",
        "opportunity_label": "Category | Region",
        "growth_pct": "QoQ Growth (%)",
    },
)

fig_ranking.update_layout(height=560)

st.plotly_chart(
    fig_ranking,
    use_container_width=True,
)

st.caption(
    "Opportunities use the original global scenario "
    "ranking. Scores indicate relative priority, "
    "not predicted financial returns."
)


# ==========================================
# SCORE BREAKDOWN
# ==========================================

st.header("3. Explain the Opportunity Score")

choices = top["opportunity_label"].tolist()

selected_opportunity = st.selectbox(
    "Select an opportunity",
    choices,
)

detail = top.loc[top["opportunity_label"] == selected_opportunity].iloc[0]

d1, d2, d3, d4 = st.columns(4)

d1.metric("Scenario Rank", f"#{int(detail['scenario_rank'])}")
d2.metric("Q2 GMV", f"R$ {detail['q2_gmv']:,.0f}")
d3.metric("QoQ GMV Growth", f"{detail['growth_pct']:+.1f}%")
d4.metric("Seller HHI", f"{detail['hhi']:.3f}")

breakdown = pd.DataFrame(
    {
        "Dimension": [
            "Growth Momentum",
            "Market Scale",
            "Seller Diversification",
            "Delivery Reliability",
        ],
        "Normalized Score": [
            detail["growth_score"],
            detail["scale_score"],
            detail["diversification_score"],
            detail["delivery_score"],
        ],
        "Weight": [
            detail["growth_weight"],
            detail["scale_weight"],
            detail["diversification_weight"],
            detail["delivery_weight"],
        ],
    }
)

breakdown["Weighted Contribution"] = breakdown["Normalized Score"] * breakdown["Weight"]

left, right = st.columns(2)

with left:
    fig_breakdown = px.bar(
        breakdown,
        x="Dimension",
        y="Weighted Contribution",
        color="Dimension",
        text_auto=".1f",
        labels={
            "Weighted Contribution": "Contribution to Opportunity Score",
        },
    )

    fig_breakdown.update_layout(
        showlegend=False,
        xaxis_tickangle=-25,
    )

    st.plotly_chart(
        fig_breakdown,
        use_container_width=True,
    )

with right:
    st.subheader("Scoring Components")

    st.dataframe(
        breakdown,
        hide_index=True,
        use_container_width=True,
        column_config={
            "Normalized Score": st.column_config.NumberColumn(format="%.2f"),
            "Weight": st.column_config.NumberColumn(format="percent"),
            "Weighted Contribution": st.column_config.NumberColumn(format="%.2f"),
        },
    )

    st.metric(
        "Total Opportunity Score",
        f"{detail['opportunity_score']:.2f}/100",
    )


# ==========================================
# RANKING STABILITY
# ==========================================

st.header("4. Weight Sensitivity Analysis")

overlap_results = []

for scenario in available_scenarios:
    scenario_top10 = set(
        data.loc[
            (data["scenario"] == scenario) & (data["scenario_rank"] <= 10),
            ["category_name", "customer_state"],
        ].itertuples(index=False, name=None)
    )

    overlap_results.append(
        {
            "Scenario": scenario,
            "Top 10 Overlap": len(baseline_top10 & scenario_top10),
        }
    )

overlap_df = pd.DataFrame(overlap_results)

fig_overlap = px.bar(
    overlap_df,
    x="Scenario",
    y="Top 10 Overlap",
    text="Top 10 Overlap",
    range_y=[0, 10],
    labels={
        "Top 10 Overlap": "Shared Opportunities (out of 10)",
    },
)

st.plotly_chart(
    fig_overlap,
    use_container_width=True,
)

st.write(
    "This chart shows how many of the Baseline Top 10 "
    "opportunities remain in the Top 10 after changing "
    "business strategy weights. It does not measure "
    "changes in their relative positions."
)


# ==========================================
# DOWNLOADABLE RANKINGS
# ==========================================

st.header("5. Opportunity Detail & Export")

export_columns = [
    "scenario",
    "scenario_rank",
    "category_name",
    "customer_state",
    "baseline_rank",
    "rank_improvement",
    "opportunity_score",
    "q1_gmv",
    "q2_gmv",
    "growth_pct",
    "q2_orders",
    "q2_active_sellers",
    "hhi",
    "on_time_delivery_pct",
]

export_df = filtered[export_columns].copy()

st.dataframe(
    export_df,
    hide_index=True,
    use_container_width=True,
)

st.download_button(
    label="Download Filtered Opportunities (CSV)",
    data=export_df.to_csv(index=False).encode("utf-8"),
    file_name="olist_opportunity_ranking.csv",
    mime="text/csv",
)

st.caption(
    "Historical Olist delivered-order data. "
    "Opportunity scores are based on analyst-defined "
    "weights and eligibility rules. "
    "They are not predictive forecasts or "
    "investment-return estimates."
)
render_footer()
