"""
Kerberos credential forwarding test app.
Verifies KRB5CCNAME propagation and PostgreSQL GSSAPI authentication.
"""

import json
import os

import psycopg2
from shiny import App, Inputs, Outputs, Session, reactive, render, ui

PG_HOST = os.environ.get("PG_HOST", "postgres-krb.localtest.me")
PG_PORT = 5432
PG_DATABASE = os.environ.get("PG_DATABASE", "krbtest")


def get_env_info():
    """Get Kerberos-relevant environment variables."""
    return {
        "KRB5CCNAME": os.environ.get("KRB5CCNAME"),
        "USER": os.environ.get("USER"),
        "LOGNAME": os.environ.get("LOGNAME"),
        "HOME": os.environ.get("HOME"),
    }


def test_db_connection():
    """Test PostgreSQL connection using Kerberos credentials."""
    krb5ccname = os.environ.get("KRB5CCNAME")
    user = os.environ.get("USER") or os.environ.get("LOGNAME")

    if not krb5ccname:
        return {
            "success": False,
            "error": "KRB5CCNAME not set",
            "KRB5CCNAME": None,
            "USER": user,
        }

    try:
        conn = psycopg2.connect(
            host=PG_HOST,
            port=PG_PORT,
            dbname=PG_DATABASE,
            user=user,
            krbsrvname="postgres",
            sslmode="disable",
            connect_timeout=10,
        )

        cursor = conn.cursor()
        cursor.execute("SELECT current_user, current_database()")
        db_user, db_name = cursor.fetchone()

        cursor.execute(
            "INSERT INTO krb_test (username) VALUES (%s) RETURNING id",
            (user,),
        )
        inserted_id = cursor.fetchone()[0]
        conn.commit()

        cursor.close()
        conn.close()

        return {
            "success": True,
            "KRB5CCNAME": krb5ccname,
            "USER": user,
            "db_user": db_user,
            "db_name": db_name,
            "inserted_id": inserted_id,
            "message": "Successfully connected using Kerberos credentials",
        }

    except psycopg2.Error as e:
        return {
            "success": False,
            "error": f"PostgreSQL connection failed: {e}",
            "KRB5CCNAME": krb5ccname,
            "USER": user,
            "pg_host": PG_HOST,
            "pg_database": PG_DATABASE,
        }
    except Exception as e:
        return {
            "success": False,
            "error": f"Unexpected error: {e}",
            "KRB5CCNAME": krb5ccname,
            "USER": user,
        }


VERBATIM_STYLE = (
    "background-color: #f6f6f6; padding: 0.75em; white-space: pre-wrap; "
    "overflow: auto; border-radius: 4px;"
)

app_ui = ui.page_fluid(
    ui.h1("Kerberos Credential Test"),
    ui.h2("Environment Variables"),
    ui.output_text_verbatim("env_json"),
    ui.hr(),
    ui.output_ui("krb_status"),
    ui.h2("Database Connection Test"),
    ui.output_ui("db_status"),
    ui.tags.pre(ui.output_text_verbatim("db_json"), style=VERBATIM_STYLE),
)


def server(input: Inputs, output: Outputs, session: Session):
    @reactive.calc
    def env_info():
        return get_env_info()

    @reactive.calc
    def db_result():
        return test_db_connection()

    @render.text
    def env_json():
        return json.dumps(env_info(), indent=2)

    @render.ui
    def krb_status():
        info = env_info()
        if info["KRB5CCNAME"]:
            return ui.markdown(
                f"**KRB5CCNAME_STATUS: SET** - `{info['KRB5CCNAME']}`"
            )
        return ui.markdown("**KRB5CCNAME_STATUS: NOT_SET**")

    @render.ui
    def db_status():
        result = db_result()
        if result["success"]:
            return ui.div(
                ui.markdown("**DB_CONNECTION_STATUS: SUCCESS**"),
                ui.div(
                    result.get("message", "Connection successful"),
                    class_="alert alert-success",
                ),
            )
        if result.get("KRB5CCNAME") is None:
            return ui.div(
                ui.markdown("**DB_CONNECTION_STATUS: KRB5CCNAME_NOT_SET**"),
                ui.div(
                    result.get("error", "KRB5CCNAME not set"),
                    class_="alert alert-danger",
                ),
            )
        return ui.div(
            ui.markdown("**DB_CONNECTION_STATUS: FAILED**"),
            ui.div(
                result.get("error", "Connection failed"),
                class_="alert alert-danger",
            ),
        )

    @render.text
    def db_json():
        return json.dumps(db_result(), indent=2)


app = App(app_ui, server)
