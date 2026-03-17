# -*- coding: utf-8 -*-
# mypy: ignore-errors
# run: shiny run app.py
import os
import json

from shiny import App, Inputs, Outputs, Session, render, ui


style = 'background-color: #f6f6f6; overflow: auto; white-space: pre-wrap; height: 12em; width: 60%'
app_ui = ui.page_fluid(
    ui.row(ui.output_text_verbatim("headers"), style=style),
    ui.row(ui.span(style="padding: 1em")),
    ui.row(ui.output_text_verbatim("env_vars"), style=style),
)

def server(input: Inputs, output: Outputs, session: Session):

    @render.text
    def headers():
        return json.dumps(dict(session.http_conn.headers), indent=4)

    @render.text
    def env_vars():
        return json.dumps(dict(os.environ), indent=4)


app = App(app_ui, server)
