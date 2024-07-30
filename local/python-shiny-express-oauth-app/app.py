from posit import connect
from shiny.express import render, session

# Runs once per startup
client = connect.Client()

# Runs once per session
@render.text
def access_token():
    user_session_token = session.http_conn.headers.get("Posit-Connect-User-Session-Token")
    return client.oauth.get_credentials(user_session_token).get("access_token")
