# -*- coding: utf-8 -*-
# mypy: ignore-errors
import json 

import jwt
from posit.connect.client import Client
from shiny import App, Inputs, Outputs, Session, render, ui

app_ui = ui.page_fluid(
        ui.row(ui.output_text_verbatim("text"),
               style='background-color: #f6f6f6; overflow: auto; white-space: pre-wrap; overflow-wrap: anywhere; height: 25em; width: 60%'))

def server(input: Inputs, output: Outputs, session: Session):
    """
    Shiny for Python example application that shows how to obtain 
    an OAuth Access Token from Connect using the `/credentials` endpoint
    by exchanging a user-session-token
    """
    session_token = session.http_conn.headers.get(
        "Posit-Connect-User-Session-Token"
    )

    @render.text
    def text():
        with Client() as client:
            credentials = client.oauth.get_credentials(session_token)
            try:
                token = jwt.decode(jwt=credentials.get("access_token"), options={"verify_signature": False})
                return json.dumps(token, indent=4) 
            except jwt.exceptions.DecodeError:
                return credentials.get("access_token", "Access Token Not Found")


app = App(app_ui, server)
