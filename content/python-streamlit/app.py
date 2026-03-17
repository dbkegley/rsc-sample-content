# -*- coding: utf-8 -*-
# mypy: ignore-errors
# run: streamlit run app.py
import os

import streamlit as st
from streamlit.web.server.websocket_headers import _get_websocket_headers

st.write("Headers:")
st.write(_get_websocket_headers())
st.write("")
st.write("Environment:")
st.write(dict(os.environ))

