# -*- coding: utf-8 -*-
# mypy: ignore-errors
# run: python app.py
import os
import json

import flask
from dash import Dash, html, Output, Input

df = None
app = Dash(__name__)

app.layout = html.Div(
    children=[
        html.Pre(html.Code(id="get-environment", children="Loading...")),
        html.Pre(html.Code(id="get-headers")),
        html.Div(id="dummy"),  # dummy element to trigger callback on page load
    ]
)

@app.callback(
    [Output("get-environment", "children"), Output("get-headers", "children")],
    Input("dummy", "children"),
)
def update_page(_):
    """
    Dash example application that shows HTTP header information and Python process environment vars.
    """

    def get_environment():
        return json.dumps(dict(os.environ), indent=4)

    def get_headers():
        return json.dumps(dict(flask.request.headers), indent=4)

    return get_environment(), get_headers()

if __name__ == "__main__":
    app.run(debug=True)
