#* @apiTitle Environment Debug Info API
#* @apiVersion 1.0.0
#* @apiDescription This Plumber API returns request headers and environment variables.

library(plumber)
library(dplyr)

#* @get /environment/vars
#* @response 200 Returns environment variables for the R process.
vars <- function() {
  formatDL(Sys.getenv(), style = "list")
}

#* @get /environment/headers
#* @response 200 Returns HTTP headers attached to the incoming request.
headers <- function(req) {
  props <- ls(req)
  result <- list()
  for (h in props) {
    # grab all the http headers
    if (startsWith(h, "HTTP")) {
      result[h] <- eval(parse(text=paste("req$", h)))
    }
  }

  result
}
