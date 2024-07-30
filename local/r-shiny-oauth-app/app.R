library(httr2)
library(shiny)

ui <- fluidPage(textOutput("access_token"))

server <- function(input, output, session) {

  # read the user-session-token header
  user_session_token <- session$request$HTTP_POSIT_CONNECT_USER_SESSION_TOKEN

  output$access_token <- renderText({
    # construct a token exchange request
    server_url <- Sys.getenv("CONNECT_SERVER", "http://127.0.0.1:3939/")
    api_key <- Sys.getenv("CONNECT_API_KEY")
    url <- paste0(server_url, "__api__/v1/oauth/integrations/credentials")
    body <- list(
      grant_type = "urn:ietf:params:oauth:grant-type:token-exchange",
      subject_token_type = "urn:posit:connect:user-session-token",
      subject_token = user_session_token
    )

    # fetch the viewer's OAuth Access Token
    httr2::request(url) |>
      httr2::req_headers(Authorization = paste("Key", api_key)) |>
      httr2::req_body_form(!!!body) |>
      req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform() |>
      httr2::resp_body_string()
  })
}

# start the Shiny app
shinyApp(ui = ui, server = server)
