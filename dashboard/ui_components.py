import html

import streamlit as st


def render_header(title, subtitle, label="MARKETPLACE ANALYTICS"):
    """Render a consistent page header."""

    st.markdown(
        f"""
        <div class="dashboard-header">
            <div class="dashboard-eyebrow">
                {html.escape(label)}
            </div>
            <h1>{html.escape(title)}</h1>
            <p>{html.escape(subtitle)}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_insight(title, message):
    """Render a business insight card."""

    st.markdown(
        f"""
        <div class="insight-card">
            <div class="insight-eyebrow">
                BUSINESS INSIGHT
            </div>
            <h4>{html.escape(title)}</h4>
            <p>{html.escape(message)}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_footer():
    """Render a shared dashboard footer."""

    st.markdown(
        """
        <div class="dashboard-footer">
            <div>MARKETPLACE GROWTH INTELLIGENCE</div>
            <div>
                Historical Olist Dataset ·
                PostgreSQL · Python · Streamlit
            </div>
            <p>
                Item GMV excludes freight and is not net revenue.
                Opportunity scores reflect analyst-defined assumptions.
            </p>
        </div>
        """,
        unsafe_allow_html=True,
    )
