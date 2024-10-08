#' Calculate cumulative species counts gouped by year, country, and/or month.
#'
#' \code{myebirdscumul} calculates cumulative species counts based on data dumped by eBird
#' (Download page: \url{http://ebird.org/ebird/downloadMyData}) after it has been cleaned with \code{ebirdclean}.
#'
#' @param mydata Data frame provided by \code{ebirdclean}.
#' @param years Range of years to calculate across, default is between 1900 and current year.
#' @param grouping Character vector specifying how the data should be grouped for counting.
#'   Must be composed of "Year", "Country", and/or "Month". This vector is passed on directly to \code{group_by_}.
#' @param cum.across Grouping of variable that cumulative counts should be done across. For example,
#'   if you want to count cumulative across months within each year, then grouping should be "Year" and
#'   cum.across = "Month".
#' @param wide Logical value specifying whether output should be returned in wide format. Defaults to FALSE.
#'
#' @return A data frame containing cumulative counts divided into specified groups. If \code{wide = FALSE}
#'   then it returns a combination of the following columns, depending on grouping specified:
#' @return "Year" Year
#' @return "Country" Country using two letter codes.
#' @return "Month" Month, using full month name (from month.name()).
#' @return "cumul" Cumulative species count for the specified Year, Country, and Month.
#' @return If in wide format, then the first column(s) consist of the values in grouping that
#' are not equal to wide, while the remaining columns are unique values of the argument specified in wide.
#'
#' @import dplyr
#' @export
#'
#' @examples \dontrun{
#' mylist <- ebirdclean() # CSV must be in working directory
#' myebirdscumul(mylist, grouping = c("Country", "Year"), years = 2013:2015, cum.across = c("Month"))
#' }
#' @author Sebastian Pardo \email{sebpardo@gmail.com}

myebirdscumul <- function (mydata, years = 1900:format(Sys.Date(), "%Y"),
                        grouping = c("Year", "Country"),
                        cum.across = "Month",
                        wide = FALSE) {
  group.options <- c("Year", "Country", NULL)
  if (!all(grouping %in% group.options) || length(grouping) > 2 ||
      length(grouping) != length(unique(grouping))) stop("grouping specified incorrectly")
  else
    if (!is.logical(wide)) stop("wide specified incorrectly, must be logical")
  else

    # Groupings, can be Year, Month, and/or country
    mydata2 <- group_by_(mydata, .dots = lazyeval::all_dots(grouping)) %>%
      filter(Year %in% years)

  if (is.null(grouping)) {
    md3 <- data.frame(location = "World")
  } else {
    md3 <- summarise(mydata2, n = n_distinct(comName)) %>%
      select_(.dots = lazyeval::all_dots(grouping))
  }

  if (length(cum.across) == 1 && cum.across == "Month") {
    for (i in 1:12) {
      t2 <- mydata2 %>%
        filter(Month %in% month.name[1:i]) %>%
        summarise(cumul = n_distinct(comName)) %>%
        rename_(.dots = setNames("cumul", month.name[i]))
      md3 <- left_join(md3, t2, by = grouping)
    }
  } else
    if (length(cum.across) == 1 && cum.across == "Year") {
      for (i in intersect(years, mydata2$Year)) {
        t2 <-
          mydata2 %>%
          filter(Year %in% min(years):i) %>%
          summarise(cumul = n_distinct(comName)) %>%
          rename_(.dots = setNames("cumul", i))
        if (is.null(grouping)) {
          md3 <- cbind(md3, t2)
        } else {
          md3 <- left_join(md3, t2, by = grouping)
        }
      }
    } else
      if (length(cum.across) == 2 && cum.across == c("Year","Month")) {
        year.range <- sort(intersect(years, mydata2$Year))
        for (i in min(year.range):max(year.range)) {
          for (k in 1:12) {
            t2 <-
              mydata2 %>%
              filter(Year < i | (Year == i & Month %in% month.name[1:k])) %>%
              #ungroup %>%
              summarise(cumul = n_distinct(comName)) %>%
              rename_(.dots = setNames("cumul", paste(i,month.name[k], sep = ".")))
            if (is.null(grouping)) {
              md3 <- cbind(md3, t2)
            } else {
              md3 <- left_join(md3, t2, by = grouping)
            }
          }
        }
      } else stop("Incorrect cum.across")

  md3[is.na(md3)] <- 0

  if (wide) {
    md3
  } else

    if (setequal(grouping, "Country") && setequal(cum.across, "Year")) {
      lcum <- tidyr::gather(md3, Year, cumul, -Country)
      lcum
    } else
      if (setequal(grouping, c("Year","Country"))) {
      lcum <- tidyr::gather(md3, Month, cumul, -Year, -Country)
      lcum
    } else
      if (setequal(grouping, c("Year"))) {
        lcum <- tidyr::gather(md3, Month, cumul, -Year)
        lcum
      } else
        if (setequal(grouping, c("Country")) & !setequal(cum.across, c("Country"))) {
          lcum <- tidyr::gather(md3, Month, cumul, -Country)
          if (setequal(cum.across, c("Year","Month"))) {
            lcum <- rename(lcum, Year.Month = Month)
            yml <- as.data.frame(do.call(rbind, strsplit(as.vector(lcum$Year.Month), "[.]")),
                                 stringsAsFactors = FALSE)
            colnames(yml) <- cum.across
            cbind(lcum, yml) %>%
              tbl_df %>%
              select(Country, Year, Month, cumul) %>%
              mutate(Month = factor(Month, levels = month.name)) %>%
              arrange(Country, Year, Month)
          } else
            lcum
        } else
          if (is.null(grouping) && length(cum.across) == 1 && cum.across == "Year") {
            lcum <- tidyr::gather(md3, Year, cumul, -location)
            lcum
          } else
            if (setequal(cum.across, c("Year","Month")) && is.null(grouping)) {
              lcum <- tidyr::gather(md3, Year.Month, cumul, -location)
              yml <- as.data.frame(do.call(rbind, strsplit(as.vector(lcum$Year.Month), "[.]")),
                                   stringsAsFactors = FALSE)
              colnames(yml) <- cum.across
              cbind(lcum, yml) %>%
                tbl_df %>%
                select(Year, Month, cumul) %>%
                mutate(Month = factor(Month, levels = month.name)) %>%
                arrange(Year, Month)
            } else stop("no grouping")

  #mutate(Year = as.character(Year), Month = factor(Month, levels = month.name)) %>%
  #%>%
  #  arrange(Year, Country, Month) %>% tbl_df %>%
  #  mutate(cumul = ifelse(is.na(cumul), 0, cumul))
}
