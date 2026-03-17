# -*- coding: utf-8 -*-
import prctl
from flask import Flask
from flask_restx import Api, Resource, reqparse

# Configure the Flask app using RestX for swagger documentation
app = Flask(__name__)
app.config["SWAGGER_UI_DOC_EXPANSION"] = "list"
app.config["RESTX_MASK_SWAGGER"] = False
app.config["ERROR_INCLUDE_MESSAGE"] = False

api = Api(
    app,
    version="0.1.0",
    title="Proc debug API",
    description="This rest API helps debug the running process",
)

ns = api.namespace('proc')
parser = reqparse.RequestParser()
parser.add_argument('signal')

@ns.route("/pdeathsig")
class ProcessSignalsApi(Resource):
    """Returns the PDEATH_SIG of this process"""

    def get(self):
        return {
            "pdeathsig": prctl.get_pdeathsig()
        }
    
    @api.doc(params={'signal': 'A parent death signal'})
    def post(self):
        args = parser.parse_args()
        sig = args['signal']
        prctl.set_pdeathsig(int(sig))
        return 200

if __name__ == "__main__":
    app.run(debug=True)
