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
    page_title="Marketplace Growth Intelligence",
    page_icon="📊",
    layout="wide",
)
# Load shared dashboard styling
css_file = Path(__file__).resolve().parent / "style.css"

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
    "Marketplace Growth Intelligence",
    "Executive Growth Overview | Brazilian E-Commerce · January 2017 – August 2018",
)


# ==========================================
# POSTGRESQL CONNECTION
# ==========================================


@st.cache_resource
def get_engine():
    db = st.secrets["postgres"]

    url = URL.create(
        drivername="postgresql+psycopg",
        username=db["user"],
        password=db["password"],
        host=db["host"],
        port=db["port"],
        database=db["database"],
    )

    return create_engine(url, pool_pre_ping=True)


@st.cache_data(ttl=600)
def load_query(sql):
    with get_engine().connect() as conn:
        return pd.read_sql_query(text(sql), conn)


# ==========================================
# LOAD ANALYTICS DATA
# ==========================================

try:
    monthly = load_query("""
        SELECT *
        FROM marts.mart_monthly_growth
        ORDER BY order_month
    """)

    decomposition = load_query("""
        SELECT *
        FROM marts.mart_growth_decomposition
        ORDER BY order_month
    """)

except Exception as e:
    st.error("Unable to connect to PostgreSQL.")
    st.exception(e)
    st.stop()


# ==========================================
# MONTHLY GROWTH OVERVIEW
# ==========================================

st.header("1. Marketplace Growth Overview")

monthly["order_month"] = pd.to_datetime(monthly["order_month"])
decomposition["order_month"] = pd.to_datetime(decomposition["order_month"])

if monthly.empty:
    st.warning("No monthly growth data available.")
    st.stop()

selected_month = st.selectbox(
    "Select reporting month",
    options=monthly["order_month"].tolist(),
    index=len(monthly) - 1,
    format_func=lambda d: d.strftime("%B %Y"),
)

current = monthly.loc[monthly["order_month"] == selected_month].iloc[0]

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric(
        "Item GMV Proxy",
        f"R$ {current['item_gmv']:,.0f}",
    )

with col2:
    st.metric(
        "Orders",
        f"{current['order_count']:,.0f}",
    )

with col3:
    st.metric(
        "Average Order Value",
        f"R$ {current['aov']:,.2f}",
    )

with col4:
    growth = current["mom_gmv_growth_pct"]

    st.metric(
        "MoM GMV Growth",
        f"{growth:+.2f}%" if pd.notna(growth) else "N/A",
    )

# ==========================================
# BUSINESS INSIGHT
# ==========================================

growth_value = current["mom_gmv_growth_pct"]

if pd.notna(growth_value):
    direction = "increased" if growth_value >= 0 else "decreased"

    insight_message = (
        f"Item GMV {direction} by "
        f"{abs(growth_value):.2f}% compared with "
        f"the previous month. "
        "Review order volume and AOV decomposition "
        "to understand the change."
    )
else:
    insight_message = "No previous reporting month is available for comparison."

render_insight(
    "Monthly Growth Snapshot",
    insight_message,
)

# ==========================================
# MONTHLY GMV TREND
# ==========================================

st.subheader("Monthly Item GMV Trend")

fig_gmv = px.line(
    monthly,
    x="order_month",
    y="item_gmv",
    markers=True,
    labels={
        "order_month": "Month",
        "item_gmv": "Item GMV (BRL)",
    },
)

fig_gmv.update_layout(
    hovermode="x unified",
    yaxis_tickprefix="R$ ",
)

st.plotly_chart(fig_gmv, use_container_width=True)


# ==========================================
# ORDERS AND AOV
# ==========================================

left, right = st.columns(2)

with left:
    st.subheader("Monthly Order Volume")

    fig_orders = px.bar(
        monthly,
        x="order_month",
        y="order_count",
        labels={
            "order_month": "Month",
            "order_count": "Orders",
        },
    )

    st.plotly_chart(
        fig_orders,
        use_container_width=True,
    )

with right:
    st.subheader("Average Order Value")

    fig_aov = px.line(
        monthly,
        x="order_month",
        y="aov",
        markers=True,
        labels={
            "order_month": "Month",
            "aov": "AOV (BRL)",
        },
    )

    st.plotly_chart(
        fig_aov,
        use_container_width=True,
    )


# ==========================================
# GROWTH DECOMPOSITION
# ==========================================

st.header("2. Growth Decomposition")

st.write(
    "Monthly changes in Item GMV are decomposed "
    "into Order Volume and Average Order Value effects."
)

decomp_long = decomposition.melt(
    id_vars=["order_month"],
    value_vars=["volume_effect", "aov_effect"],
    var_name="growth_driver",
    value_name="gmv_effect",
)

decomp_long["growth_driver"] = decomp_long["growth_driver"].replace(
    {
        "volume_effect": "Order Volume Effect",
        "aov_effect": "AOV Effect",
    }
)

fig_decomp = px.bar(
    decomp_long,
    x="order_month",
    y="gmv_effect",
    color="growth_driver",
    barmode="relative",
    labels={
        "order_month": "Month",
        "gmv_effect": "GMV Change (BRL)",
        "growth_driver": "Growth Driver",
    },
)

st.plotly_chart(
    fig_decomp,
    use_container_width=True,
)

st.caption(
    "Item GMV excludes freight. "
    "Growth decomposition is descriptive, not causal. "
    "Historical delivered-order data may have "
    "incomplete boundary-period coverage."
)
render_footer()
