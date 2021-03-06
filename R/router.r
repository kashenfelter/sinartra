#' Router object.
#' The router object coordinates matching urls to functions. 
#' 
#' Add possible route using the appropriate http verb (get, post, put,
#' delete). Currently only get is implemented.  These methods have two 
#' arguments: \code{route}, the description of the url to match, and the
#' \code{callback} to run when the route is matched.
#'
#' Route urls have a special syntax.  They are basically paths but with two
#' special keywords: \code{:param} which matches a single component and
#' \code{*} which will match anything.
#'
#' \itemize{
#'  \item \code{hello.html} matches \code{hello.html only}
#'  \item \code{packages/:package.html} will match \code{packages/a.html},
#'     \code{packages:/my-package.html} and so on, and the callback will be
#'     called with an argument named package containing "a" and "my-package"
#'     respectively.
#'  \item \code{*.html} will match anything ending in \code{.html} and 
#'     callback will be called with a "splat" argument
#' }
#' @name Router
#' @import evaluate stringr
#' @export
Router <- mutatr::Object$clone()$do({
  self$matchers  <- list()
  baseUrl  <- ""
  filePath <- getwd()

  self$base_url  <- function(newBaseUrl = NULL) {
    if ( ! is.null(newBaseUrl) ) {
      baseUrl <<- newBaseUrl
    } 
    baseUrl
  }
  
  self$file_path <- function(newFilePath = NULL) {
    if ( ! is.null(newFilePath) ) {
      filePath <<- newFilePath
    } 
    filePath
  }
  
  self$get <- function(route, callback) {
    rm <- route_matcher(route)
    rm$callback <- callback
    
    self$matchers[[length(self$matchers) + 1]] <- rm
  }
    
  self$route <- function(path, query) {
    p <- stringr::str_replace(path, self$base_url(), "")
    slash = self$matchers[[4]]
    
    for(matcher in self$matchers) {
      matchOutput = matcher$match(p)
      if (matchOutput) {
        params <- matcher$params(p)
        params$query <- query
        
        call <- bquote(do.call(.(matcher$callback), .(params)))
        res <- try_capture_stack(call, sys.frame())
        
        if (is.error(res)) {
          traceback <- stringr::str_c(create_traceback(res$calls), collapse = "\n")
          return(stringr::str_c("ERROR: ", res$message, "\n\n", traceback))
        }
        
        if (!is.pass(res)) return(res)
      }
    }
    
    # If none match, return 404
    self$error(404)
  }
    
  combine_url <- function(y) {
    if(stringr::str_length(self$base_url()) < 1) return(y)
    
    u <- self$base_url()
    if(stringr::str_sub(u, start = -1) == "/") {
      u <- stringr::str_sub(u, end = -2)
    }
    
    # url <- str_c(u, y, sep = "/")
    url <- stringr::str_c(u, y)
    url
  }
  self$comb <- combine_url
  combine_path <- function(y){ 
    if(stringr::str_sub(y, end = 1) == "/"){
      y
    } else {
      file.path(self$file_path(), y)
    }
  }
  
  self$error <- function(..., path = ""){
    u <- combine_url(path)
    error(..., path = u)
  }
  
  self$static_file <- function(path, ...) {
    p <- combine_path(path)
    static_file(path = p, ...)    
  }

  self$redirect <- function(url, ...) {
    u <- combine_url(url)
    redirect(url = u, ...)
  }
  
  self$render_brew <- function(..., path){
    if(missing(path)) path <- self$file_path()
    
    render_brew(..., path = path, parent = parent.frame())
  }
  
})


is.error <- function(x) inherits(x, "simpleError")
