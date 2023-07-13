import sys
import json

# Simple WSGI application.
# Derived from https://peps.python.org/pep-3333/#error-handling
def simple_app(environ, start_response):
    try:
        path_info = environ.get("PATH_INFO", "")
        if path_info == "/error":
            # When "/error" is requested, force an exception to be thrown,
            # which then falls into the except clause below.
            1 / 0

        # regular application code here
        status = "200 Froody"
        response_headers = [("content-type", "application/json")]
        start_response(status, response_headers)
        data = json.dumps({"msg": "Hello, Simple WSGI!"})
        return data.encode("UTF-8")
    except:
        # XXX should trap runtime issues like MemoryError, KeyboardInterrupt
        #     in a separate handler before this bare 'except:'...
        status = "500 Oops"
        response_headers = [("content-type", "application/json")]
        start_response(status, response_headers, sys.exc_info())
        data = json.dumps({"msg": "Oh, no! What have you done, Simple WSGI?"})
        return data.encode("UTF-8")


app = simple_app
