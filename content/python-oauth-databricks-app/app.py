# -*- coding: utf-8 -*-
import os

import pandas as pd

from posit.connect.external.databricks import viewer_credentials_provider
from shiny.ui.dataframe import output_data_frame

from databricks import sql
from databricks.sdk.service.iam import CurrentUserAPI
from databricks.sdk.core import ApiClient, Config

from shiny import App, Inputs, Outputs, Session, render, ui

DATABRICKS_HOST = os.getenv("DATABRICKS_HOST")
DATABRICKS_HOST_URL = f"https://{DATABRICKS_HOST}"
DATABRICKS_SQL_PATH = os.getenv("DATABRICKS_SQL_PATH")

app_ui = ui.page_fluid(ui.output_text("text"), ui.output_data_frame("result"))


def server(input: Inputs, output: Outputs, session: Session):
    """
    Shiny for Python example application that shows user information and
    the first few rows from a table hosted in Databricks.
    """
    session_token = session.http_conn.headers.get(
        "Posit-Connect-User-Session-Token"
    )
    credentials_provider = viewer_credentials_provider(
        user_session_token=session_token
    )

    if DATABRICKS_HOST == None or DATABRICKS_SQL_PATH == None:
        raise ValueError("DATABRICKS_HOST and DATABRICKS_SQL_PATH environment variables must be set")

    @render.data_frame
    def result():
        query = "SELECT * FROM samples.nyctaxi.trips LIMIT 10;"

        with sql.connect(
            server_hostname=DATABRICKS_HOST,
            http_path=DATABRICKS_SQL_PATH,
            auth_type="databricks-oauth",
            credentials_provider=credentials_provider,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(query)
                rows = cursor.fetchall()
                df = pd.DataFrame(
                    rows, columns=[col[0] for col in cursor.description]
                )
                return df

    @render.text
    def text():
        cfg = Config(
            host=DATABRICKS_HOST_URL, credentials_provider=credentials_provider
        )
        databricks_user_info = CurrentUserAPI(ApiClient(cfg)).me()
        return f"Hello, {databricks_user_info.display_name}!"


app = App(app_ui, server)
