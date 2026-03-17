library(shiny)

shinyApp(
  ui = basicPage(
    verbatimTextOutput("headers", placeholder = TRUE),
    verbatimTextOutput("env_vars", placeholder = TRUE)
  ),
  server = function(input, output, session) {
    headers <- function() {
      props <- ls(session$request)
      result <- list()
      for (h in props) {
        # grab all the http headers
        if (startsWith(h, "HTTP")) {
          result[h] <- eval(parse(text=paste("session$request$", h)))
        }
      }
      paste(names(result),result,sep="=",collapse="\n")
    }

    env <- Sys.getenv()
    output$env_vars <- renderText(paste(names(env),env,sep="=",collapse="\n"))
    output$headers <- renderText(headers())
  }
)


