import pandas as pd
import plotly.express as px
import streamlit as st
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from pathlib import Path
from ui_components import render_header, render_insight, render_footer

# ==========================================
# PAGE CONFIG
# ==========================================

st.set_page_config(
    page_title="Category & Seller Health",
    page_icon="🛍️",
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
    "Category & Seller Health",
    "Category Growth Contribution · Seller Diversification · Marketplace Supply Health",
)


# ==========================================
# DATABASE CONNECTION
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
# LOAD DATA
# ==========================================

try:
    category = load_data("""
        SELECT
            order_month,
            category_name,
            item_gmv,
            order_count,
            previous_month_gmv,
            gmv_change,
            mom_growth_pct,
            growth_contribution_pct
        FROM marts.mart_category_growth
    """)

    seller = load_data("""
        SELECT
            order_month,
            category_name,
            active_sellers,
            category_gmv,
            hhi,
            top_seller_share_pct
        FROM marts.mart_seller_concentration
    """)

except Exception as e:
    st.error("Unable to load PostgreSQL analytics data.")
    st.exception(e)
    st.stop()


# ==========================================
# CLEAN DATA TYPES
# ==========================================

category["order_month"] = pd.to_datetime(category["order_month"])

seller["order_month"] = pd.to_datetime(seller["order_month"])

for col in [
    "item_gmv",
    "previous_month_gmv",
    "gmv_change",
    "mom_growth_pct",
    "growth_contribution_pct",
]:
    category[col] = pd.to_numeric(category[col], errors="coerce")

for col in [
    "category_gmv",
    "hhi",
    "top_seller_share_pct",
]:
    seller[col] = pd.to_numeric(seller[col], errors="coerce")


# ==========================================
# SIDEBAR FILTERS
# ==========================================

st.sidebar.header("Analysis Filters")

months = sorted(category["order_month"].dropna().unique())

selected_month = st.sidebar.selectbox(
    "Reporting Month",
    months,
    index=len(months) - 1,
    format_func=lambda d: pd.Timestamp(d).strftime("%B %Y"),
)

minimum_gmv = st.sidebar.number_input(
    "Minimum Category GMV (BRL)",
    min_value=0,
    value=10000,
    step=5000,
)

month_category = category[category["order_month"] == selected_month].copy()

month_seller = seller[seller["order_month"] == selected_month].copy()

# Join two marts at month + category grain.
combined = month_category.merge(
    month_seller,
    on=["order_month", "category_name"],
    how="left",
    validate="one_to_one",
)

# Keep only categories above the GMV threshold.
filtered = combined[combined["item_gmv"] >= minimum_gmv].copy()


# ==========================================
# TOP KPIs
# ==========================================

st.header("1. Category Performance Overview")

kpi1, kpi2, kpi3 = st.columns(3)

with kpi1:
    st.metric(
        "Active Categories",
        f"{len(filtered):,}",
    )

with kpi2:
    st.metric(
        "GMV in Filtered Categories",
        f"R$ {filtered['item_gmv'].sum():,.0f}",
    )

with kpi3:
    st.metric(
        "Median Seller HHI",
        (f"{filtered['hhi'].median():.3f}" if filtered["hhi"].notna().any() else "N/A"),
    )

st.caption(
    "KPI cards reflect the selected month and "
    "minimum GMV filter. Filtered-category GMV "
    "is not necessarily total marketplace GMV."
)

if filtered.empty:
    st.warning(
        "No categories match the selected threshold. Try reducing Minimum Category GMV."
    )
    st.stop()


# ==========================================
# BUSINESS INSIGHT
# ==========================================

top_category = filtered.sort_values("item_gmv", ascending=False).iloc[0]

render_insight(
    "Category Performance Snapshot",
    (
        f"{top_category['category_name']} has the highest "
        f"Item GMV among the displayed categories, "
        f"at R$ {top_category['item_gmv']:,.0f}. "
        "Review seller concentration alongside growth "
        "before interpreting category health."
    ),
)

# ==========================================
# CATEGORY GMV RANKING
# ==========================================

st.header("2. Top Categories by Item GMV")

top_categories = (
    filtered.sort_values("item_gmv", ascending=False)
    .head(15)
    .sort_values("item_gmv", ascending=True)
)

fig_gmv = px.bar(
    top_categories,
    x="item_gmv",
    y="category_name",
    orientation="h",
    labels={
        "item_gmv": "Item GMV (BRL)",
        "category_name": "Category",
    },
    hover_data=["order_count"],
)

fig_gmv.update_layout(
    height=550,
    xaxis_tickprefix="R$ ",
)

st.plotly_chart(
    fig_gmv,
    use_container_width=True,
)


# ==========================================
# GROWTH CONTRIBUTION
# ==========================================

st.header("3. Category Growth Contribution")

st.write(
    "Which categories contributed the largest "
    "positive and negative changes in monthly GMV?"
)

contribution = filtered.dropna(subset=["gmv_change"]).sort_values(
    "gmv_change", ascending=False
)

positive = contribution.head(10)

negative = contribution.sort_values("gmv_change").head(10)

left, right = st.columns(2)

with left:
    st.subheader("Largest GMV Increases")

    fig_positive = px.bar(
        positive.sort_values("gmv_change"),
        x="gmv_change",
        y="category_name",
        orientation="h",
        labels={
            "gmv_change": "GMV Change (BRL)",
            "category_name": "Category",
        },
    )

    st.plotly_chart(
        fig_positive,
        use_container_width=True,
    )

with right:
    st.subheader("Largest GMV Decreases")

    fig_negative = px.bar(
        negative.sort_values("gmv_change"),
        x="gmv_change",
        y="category_name",
        orientation="h",
        labels={
            "gmv_change": "GMV Change (BRL)",
            "category_name": "Category",
        },
    )

    st.plotly_chart(
        fig_negative,
        use_container_width=True,
    )

st.caption(
    "GMV changes use the previous reporting month. "
    "The charts rank increases and decreases by "
    "absolute GMV change, not percentage growth. "
    "The minimum GMV filter applies to the current month."
)


# ==========================================
# SELLER CONCENTRATION HHI
# ==========================================

st.header("4. Seller Concentration Analysis")

st.write(
    "HHI measures how concentrated a category's "
    "GMV is across sellers. Higher values indicate "
    "greater seller concentration."
)

hhi_data = filtered.dropna(subset=["hhi"]).copy()

fig_hhi = px.scatter(
    hhi_data,
    x="active_sellers",
    y="hhi",
    size="item_gmv",
    hover_name="category_name",
    hover_data={
        "top_seller_share_pct": ":.1f",
        "item_gmv": ":,.2f",
    },
    labels={
        "active_sellers": "Active Sellers",
        "hhi": "Seller HHI (0–1)",
        "item_gmv": "Item GMV (BRL)",
    },
)

fig_hhi.update_layout(height=500)

st.plotly_chart(
    fig_hhi,
    use_container_width=True,
)


# ==========================================
# CATEGORY HEALTH TABLE
# ==========================================

st.header("5. Category Health Detail")

display_columns = [
    "category_name",
    "item_gmv",
    "order_count",
    "gmv_change",
    "mom_growth_pct",
    "active_sellers",
    "hhi",
    "top_seller_share_pct",
]

st.dataframe(
    filtered[display_columns].sort_values("item_gmv", ascending=False),
    use_container_width=True,
    hide_index=True,
    column_config={
        "category_name": "Category",
        "item_gmv": st.column_config.NumberColumn("Item GMV (BRL)", format="%.2f"),
        "order_count": "Orders",
        "gmv_change": st.column_config.NumberColumn("GMV Change", format="%.2f"),
        "mom_growth_pct": st.column_config.NumberColumn(
            "MoM Growth (%)", format="%.2f"
        ),
        "active_sellers": "Active Sellers",
        "hhi": st.column_config.NumberColumn("Seller HHI", format="%.4f"),
        "top_seller_share_pct": st.column_config.NumberColumn(
            "Top Seller Share (%)", format="%.2f"
        ),
    },
)

st.caption(
    "Historical Olist delivered orders, "
    "January 2017 – August 2018. "
    "Item GMV excludes freight and is not profit. "
    "HHI is a relative concentration indicator, "
    "not a direct measure of financial risk."
)
render_footer()
