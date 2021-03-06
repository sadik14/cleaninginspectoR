
#' Find duplicates / non-unique values in a variable
#'
#' @param data a dataframe
#' @param duplicate.column.name the name of the column the dataframe to be checked for duplicates as a string (in quotes)
#' @return A dataframe with one row per potential issue. It has columns for the corresponding row index in the original data; the suspicious value; the variable name in the original dataset in which the suspicious value occured; A description of the issue type.
#' @examples
#' # a test dataset with 1000 rows; one numeric variable and one id variable
#' testdf <- data.frame(numeric_var = runif(10), unique_ids = c(1, 2, 3, 4, 5, 6, 7, 8, 1, 3))
#' # find duplicates in the unique_ids column:
#' find_duplicates(data, "unique_ids")
#' @export
find_duplicates <- function(data, duplicate.column.name) {

  ### sanitise inputs
  if (!is.data.frame(data)) stop("first input must be a data frame. Use typeof(data) to find out what you have instead") # ensure first input is a dataframe
  # ensure all the variable names are in the dataframe
  if (!(duplicate.column.name %in% names(data))) stop(paste0("The name of the column to check for duplication must be found in the data headers"))

  duplicate <- data[[duplicate.column.name]] %>%
    duplicated() %>%
    which()
  if (length(duplicate) == 0) {

    return(empty_issues_table())
  }
  duplicate <- data.frame(index = duplicate, value = data[[duplicate.column.name]][duplicate],stringsAsFactors = F)
  colnames(duplicate) <- c("index", "value")
  duplicate <- data.frame(duplicate, variable = duplicate.column.name,
                     has_issue = T, issue_type = paste("duplicate in", duplicate.column.name),stringsAsFactors = F)
  as.data.frame(duplicate,stringsAsFactors = F)
}



#' Search UUID column, then find duplicates / non-unique values in it
#'
#' @param data a dataframe
#' @details searches for "uuid" (not case sensitive) in the variable names. Identifies duplicate values in the first variable that matches the search.
#' This function uses the more generic `find_duplicates()` function, which you should use if your id column doesn't contain "uuid"
#' @return A dataframe with one row per potential issue. It has columns for the corresponding row index in the original data; the suspicious value; the variable name in the original dataset in which the suspicious value occured; A description of the issue type.
#' @examples
#' # a test dataset with 1000 rows; one numeric variable and one id variable
#' testdf <- data.frame(numeric_var = runif(10), unique_ids = c(1, 2, 3, 4, 5, 6, 7, 8, 1, 3))
#' # find duplicates in the unique_ids column:
#' find_duplicates_uuid(data)
#' @export
find_duplicates_uuid <- function(data) {

  ### sanitise inputs
  if (!is.data.frame(data)) stop("first input must be a data frame. Use typeof(data) to find out what you have instead") # ensure first input is a dataframe
  ### find uuid column and check it is a single value
  uuid.name <- grep("uuid", names(data), value = T, ignore.case = T)
  if (length(uuid.name) == 0) {
    warning("Could not find the uuid automatically in the dataset. Please provide the name of the uuid column as a parameter for find_duplicates()")
    return(empty_issues_table())
  }
  if (length(uuid.name) > 1) {
    uuid.name <- uuid.name[1]
  }

  return(find_duplicates(data, uuid.name))
}



#' Find outliers in all numerical columns of a dataset
#'
#' @param data a dataframe
#' @details Searches for values that are outside more than three standard deviations from the mean.
#' If fewer outliers are found when the data is log-transformed before the check, only outliers in the log-transformed data are returned.
#' @return A dataframe with one row per potential issue. It has columns for the corresponding row index in the original data; the suspicious value; the variable name in the original dataset in which the suspicious value occured; A description of the issue type.
#' @export
find_outliers <- function(data) {
  ## calculate both normal and log normal outliers for the whole dataframe
  outliers_normal <- data %>% data_validation_outliers_normal()
  outliers_log_normal <- data %>% data_validation_outliers_log_normal()
  outliers <- lapply(names(data), function(x) {
    ## return an empty issues dataframe of issues if no outliers are found
    if ((nrow(outliers_log_normal[[x]]) == 0) & (nrow(outliers_normal[[x]]) ==
      0)) {
      return(empty_issues_table())
    }
    else if (nrow(outliers_log_normal[[x]]) < nrow(outliers_normal[[x]])) { ## for each variable, select the method with fewer outliers

      data.frame(outliers_log_normal[[x]],
        variable = rep(x, nrow(outliers_log_normal[[x]])), # rep(...,nrow()) makes this work for no rows etc.
        has_issue = rep(T, nrow(outliers_log_normal[[x]])),
        issue_type = rep("log normal distribution outlier", nrow(outliers_log_normal[[x]])), stringsAsFactors = F
      )
    }
    else {
      data.frame(outliers_normal[[x]],
        variable = rep(x, nrow(outliers_normal[[x]])),
        has_issue = rep(T, nrow(outliers_normal[[x]])),
        issue_type = rep("normal distribution outlier", nrow(outliers_normal[[x]])),
        stringsAsFactors = F
      )

    }
  }) %>% do.call(rbind, .)
  if (nrow(outliers) == 0) {
    return(empty_issues_table())
  }
  outliers$variable <- as.character(outliers$variable)
  return(outliers)
}

#' Find all responses in all columns that might be "specify other" responses to a multiple choice question
#'
#' @param data a dataframe
#' @details Performs a non-case sensitive search for "other" in english and french along the column names of the dataframe and returns all unique values and their frequency.
#' @return A dataframe with one row per potential issue. It has columns for the corresponding row index in the original data; the suspicious value; the variable name in the original dataset in which the suspicious value occured; A description of the issue type.
#' @export
find_other_responses <- function (data)
{
  counts<-data %>% select_other_columns
  if(ncol(counts) == 0){return(empty_issues_table())}
  counts <- counts %>% (tidyr::gather)

  if(ncol(counts) == 0){return(empty_issues_table())}else{
  #%>% extract(.,colSums(!is.na(.))<nrow(.))
  counts %<>% filter(!is.na(value)) %>% filter(!value %in% c("", TRUE, FALSE, 1, 0, "VRAI", "FAUX", "TRUE", "FALSE", "<NA>", "NA"))

  counts %<>% group_by(key,value) %>% summarise(count=length(value)) %>% filter(!is.na(value))
    #summarise_all(funs(sum, na.rm = T))

  others <- counts %>% as.data.frame

  if (nrow(others) == 0) {
    return(empty_issues_table())
  }

  others <- others %>% mutate(value = paste0(value," /// instances: ",count)) %>% select(variable = key,value)

  others <- data.frame(index = NA, others[, c("value", "variable")],
                       has_issue = T, issue_type = "'other' response. may need recoding.", stringsAsFactors = F)

  return(others)
  }
}


#' Search column names for words often used in senstive variables
#'
#' @param data a dataframe
#' @param i.know.this.check.is.insufficient optional: if not set to TRUE, this function throws a warning.
#' @details Searches column headers for keywords "gps", "phone","latitude", "longitude" and "phone" (not case sensitive)
#' WARNING: this check is rudimentary and does not suffice in any way to insure protection of sensitive information.
#' @return A dataframe with one row per potential issue. It has columns for the corresponding row index in the original data; the suspicious value; the variable name in the original dataset in which the suspicious value occured; A description of the issue type.
#' @export
sensitive_columns <- function (data, i.know.this.check.is.insufficient=F)
{
  sensitive.cols<- grep("GPS|gps|phone|Latitude|Longitude|Phone", x = names(data), value = T,ignore.case = T)
  if(length(sensitive.cols) == 0){return(empty_issues_table())}
  sensitive.cols <- data.frame(index = NA, value = NA, variable = sensitive.cols,
                       has_issue = TRUE, issue_type = "Potentially sensitive information. Please ensure all PII is removed",stringsAsFactors = F)
  if(!i.know.this.check.is.insufficient){warning("sensitive_columns() is rudimentary and does not provide ANY data protection.")}
  return(sensitive.cols)
}


#' Check kobo interview time
#'
#'
#' @param data Dataframe with "start" and "end" columns.
#' @param duration_threshold_lower Minimum number of minutes to complete the form
#' @param duration_threshold_upper Maximum number of minutes to complete the form
#' @return A dataframe with one row per potential issue. It has columns for the corresponding row index in the original data; the suspicious value (survey that is longer or shorter than it should be); the variable name in the original dataset in which the suspicious value occured; A description of the issue type.
#' @export
check_time <- function(data, duration_threshold_lower=15, duration_threshold_upper=100){
  ## Input sanitation
  if(!is.data.frame(data))stop("data needs to be a dataframe!")
  if(!("start" %in% names(data)))stop("data needs to have a column called 'start' for this function work")
  if(!("end" %in% names(data)))stop("data needs to have a column called 'end' for this function work")
  ## pick apart the date and time parts of the start and end columns and identify those survey completed on different days
  df_col_separated <- data %>% separate(start, c("start_date", "start_time"), "T") %>%
    separate(end, c("end_date", "end_time"), "T")
  df_col_separated$days_diff <- difftime(as.POSIXct(df_col_separated$end_date), as.POSIXct(df_col_separated$start_date), units="days")
  same_date <- df_col_separated[((as.numeric(df_col_separated$days_diff))==0),]
  different_date <- df_col_separated[((as.numeric(df_col_separated$days_diff))>0),]

  #Making time into numeric so that calculations can be done
  same_date$start_time <- round(as.difftime(same_date$start_time, units = "mins"),2)
  same_date$end_time <- round(as.difftime(same_date$end_time, units = "mins"),2)
  same_date$duration_min <- as.numeric(same_date$end_time-same_date$start_time)
  same_date$time_short_flag <- ifelse(same_date$duration_min<=duration_threshold_lower,1,0)
  same_date$time_long_flag <- ifelse(same_date$duration_min>=duration_threshold_upper,1,0)

  ## seperate the filtering into those surveys that are too long and those that are too short
  too_short <- same_date %>% dplyr::filter(time_short_flag == 1)
  too_short$issue_type <- "form duration too short"
  too_long <- same_date %>% dplyr::filter(time_long_flag == 1)
  too_long$issue_type <- "form duration too long"

  ## bind and reformat the two culprits !!!
  time_problems <- rbind(too_short, too_long)
  colnames(time_problems)[grep("uuid", colnames(time_problems))] <- "uuid"
  time_problems$variable <- "Completion Duration (min)"
  time_problems$has_issue <- "TRUE"
  time_problems$issue_type <- "form duration too short"

  time_grab <- time_problems %>% dplyr::select(uuid,duration_min,variable,	has_issue,	issue_type)
  names(time_grab) <- c("index",	"value",	"variable",	"has_issue",	"issue_type")
  return(time_grab)
}

