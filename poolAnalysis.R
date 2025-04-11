#Default path of the function
script_path <- dirname(rstudioapi::getSourceEditorContext()$path)
setwd(script_path)

library(jsonlite)
library(reticulate)
library(digest)
library(stringr)
library(rmarkdown)
source("global.R")
use_condaenv_from_file("py_env.txt")
################################################
################################################
#Pool analysis and call for new items
################################################
################################################
#Read current item bank
item_bank<-jsonlite::fromJSON("item_bank.json")

################################################
#Investigate the item bank and find areas needing new items
##Construct functions for item bank investigations
check_bounds <- function(item_bank,df,dimension) {
  # Calculate the proportions of each discipline in the item bank
  discipline_proportions <- prop.table(table(item_bank[,names(item_bank)==dimension]))
  # Initialize a character vector to store the results of the bounds check
  bounds_check <- character(nrow(df))
  proportion_check<-bounds_check
  # Loop through each discipline in the disciplines_df
  for (i in 1:nrow(df)) {
    discipline <- df[,1][i]
    lower_bound <- df$LowerBound[i]
    upper_bound <- df$UpperBound[i]
    
    # Check if the proportion of the discipline in the item bank is within the bounds
    proportion <- discipline_proportions[discipline]
    proportion_check[i]<-proportion
    if (is.na(proportion)) {
      # If the discipline is not present in the item bank, treat it as 0 proportion
      proportion <- 0
    }
    
    if (proportion < lower_bound) {
      bounds_check[i] <- "lower"
    } else if (proportion > upper_bound) {
      bounds_check[i] <- "higher"
    } else {
      bounds_check[i] <- "within"
    }
  }
  # Return the character vector indicating the status of each discipline
  bounds_check<-cbind(df[,1],bounds_check,proportion_check)
  colnames(bounds_check)[1]<-dimension
  colnames(bounds_check)[2]<-"inventoryCheck"
  colnames(bounds_check)[3]<-"inventoryVolume"
  bounds_check<-as.data.frame(bounds_check)
  bounds_check[,3]<-as.numeric(bounds_check[,3])
  bounds_check
}
################################################
################################################
##Core checking function for a given item_bank
itembankCheck<-function(item_bank){
  
  #USMLE Step 1 specifications as a checklist
  json_disciplines <- '{"Step 1 Discipline Specifications": [{"disciplines": "Pathology","LowerBound": 0.44,"UpperBound": 0.52},{"disciplines": "Physiology","LowerBound": 0.25,"UpperBound": 0.35},{"disciplines": "Pharmacology","LowerBound": 0.15,"UpperBound": 0.22},{"disciplines": "Biochemistry & Nutrition","LowerBound": 0.14,"UpperBound": 0.24},{"disciplines": "Microbiology","LowerBound": 0.10,"UpperBound": 0.15},{"disciplines": "Immunology","LowerBound": 0.06,"UpperBound": 0.11},{"disciplines": "Gross Anatomy & Embryology","LowerBound": 0.11,"UpperBound": 0.15},{"disciplines": "Histology & Cell Biology","LowerBound": 0.08,"UpperBound": 0.13},{"disciplines": "Behavioral Sciences","LowerBound": 0.08,"UpperBound": 0.13},{"disciplines": "Genetics","LowerBound": 0.05,"UpperBound": 0.09}]}'
  json_contents <- '{"Step 1 Test Content Specifications": [{"systems": "Human Development","LowerBound": 0.01,"UpperBound": 0.03},{"systems": "Blood & Lymphoreticular/Immune Systems","LowerBound": 0.09,"UpperBound": 0.13},{"systems": "Behavioral Health & Nervous Systems/Special Senses","LowerBound": 0.10,"UpperBound": 0.14},{"systems": "Musculoskeletal, Skin & Subcutaneous Tissue","LowerBound": 0.07,"UpperBound": 0.12},{"systems": "Cardiovascular System","LowerBound": 0.06,"UpperBound": 0.11},{"systems": "Respiratory & Renal/Urinary Systems","LowerBound": 0.11,"UpperBound": 0.15},{"systems": "Gastrointestinal System","LowerBound": 0.05,"UpperBound": 0.10},{"systems": "Reproductive & Endocrine Systems","LowerBound": 0.12,"UpperBound": 0.16},{"systems": "Multisystem Processes & Disorders","LowerBound": 0.08,"UpperBound": 0.12},{"systems": "Biostatistics & Epidemiology/Population Health","LowerBound": 0.04,"UpperBound": 0.06},{"systems": "Social Sciences: Communication and Interpersonal Skills","LowerBound": 0.06,"UpperBound": 0.09}]}'
  json_competencies <- '{"Step 1 Physician Tasks/Competencies Specifications": [{"competencies": "Medical Knowledge: Applying Foundational Science Concepts","LowerBound": 0.60,"UpperBound": 0.70},{"competencies": "Patient Care: Diagnosis","LowerBound": 0.20,"UpperBound": 0.25},{"competencies": "Communication and Interpersonal Skills","LowerBound": 0.06,"UpperBound": 0.09},{"competencies": "Practice–based Learning & Improvement","LowerBound": 0.04,"UpperBound": 0.06}]}'

  #Necessary steps to convert the checklist to workable data
  ##Parse JSON
  discipline_data <- fromJSON(json_disciplines)
  content_data <- fromJSON(json_contents)
  competency_data <- fromJSON(json_competencies)
  ##Extract discipline, content, and competency lists with weights
  disciplines_df <- discipline_data$`Step 1 Discipline Specifications`
  systems_df <- content_data$`Step 1 Test Content Specifications`
  competencies_df <- competency_data$`Step 1 Physician Tasks/Competencies Specifications`
  ##Define the lists of Discipline, System, and Tasks/Competencies
  disciplines <- unique(disciplines_df[,1])
  systems <- unique(systems_df[,1])
  competencies <-  unique(competencies_df[,1])
  
  disciplines_bounds_check_result <- check_bounds(item_bank, disciplines_df,dimension='disciplines')
  systems_bounds_check_result <- check_bounds(item_bank, systems_df,dimension='systems')
  competencies_bounds_check_result <- check_bounds(item_bank, competencies_df,dimension='competencies')
  ##Areas needing new items in terms of specification combinations (we call the areasNeedItems as "waiting list")
  areasNeedItems<-expand.grid(disciplines_bounds_check_result[disciplines_bounds_check_result$inventoryCheck=='lower',1],
                              systems_bounds_check_result[systems_bounds_check_result$inventoryCheck=='lower',1],
                              competencies_bounds_check_result[competencies_bounds_check_result$inventoryCheck=='lower',1])
  colnames(areasNeedItems)<-c("disciplines","systems","competencies")
  itembankCheck_res<-list()
  
  
  itembankCheck_res[[1]]<-areasNeedItems
  itembankCheck_res[[2]]<-cbind(disciplines_bounds_check_result,disciplines_df[,-1])
  itembankCheck_res[[3]]<-cbind(systems_bounds_check_result,systems_df[,-1])
  itembankCheck_res[[4]]<-cbind(competencies_bounds_check_result,competencies_df[,-1])
  
  
  currentItembankInfo<-itembankCheck_res
  names(currentItembankInfo)<-c('Areas needing more items','(from discipline)current itembank status with current volume and the lower&uppper bounds required by NBME','(from system)current itembank status with current volume and the lower&uppper bounds required by NBME','(from competency) current itembank status with current volume and the lower&uppper bounds required by NBME')
  my_json <- toJSON(currentItembankInfo, pretty = TRUE)
  output_file <- "currentItembankInfo.json"
  writeLines(my_json, con = output_file)
  itembankCheck_res
  
}

#Report the pool analysis result
report_poolAnalysis <- function(Agent_poolAnalysis, areasNeedItems, output_format = "html") {
  # Create temp markdown file
  temp_md <- tempfile(fileext = ".Rmd")
  
  # Set output file name with full path
  output_dir <- getwd()
  output_file <- file.path(output_dir, paste0("item_bank_analysis.", output_format))
  
  # Create markdown content
  md_content <- c(
    "---",
    "title: \"Item Bank Analysis Report\"",
    "date: \"`r format(Sys.time(), '%Y-%m-%d')`\"",
    paste0("output: ", output_format, "_document"),
    "---",
    "",
    "## Analysis Results\n",
    Agent_poolAnalysis$response$choices[[1]]$message$content,
    "\n\n",
    "## Here are the detailed areas needing more items:\n"
  )
  
  # Add table if areasNeedItems is a dataframe
  if (is.data.frame(areasNeedItems) && nrow(areasNeedItems) > 0) {
    header <- paste("|", paste(names(areasNeedItems), collapse = " | "), "|")
    separator <- paste("|", paste(rep("---", ncol(areasNeedItems)), collapse = " | "), "|")
    
    rows <- apply(areasNeedItems, 1, function(row) {
      paste("|", paste(row, collapse = " | "), "|")
    })
    
    table_content <- c(header, separator, rows)
    md_content <- c(md_content, table_content)
  } else {
    md_content <- c(md_content, "No areas found that need more items.")
  }
  
  # Write to temp file
  writeLines(md_content, temp_md)
  
  # Check for rmarkdown package
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop("Please install rmarkdown: install.packages('rmarkdown')")
  }
  
  # Render document
  tryCatch({
    result_file <- rmarkdown::render(
      input = temp_md,
      output_file = basename(output_file),
      output_dir = output_dir,
      quiet = FALSE
    )
    
    if (file.exists(result_file)) {
      message(paste("Report saved to:", result_file))
    } else {
      warning("File generation may have failed")
    }
  }, error = function(e) {
    message("Error in rendering: ", e$message)
    # If PDF fails, try HTML
    if (output_format == "pdf") {
      message("PDF generation failed. Trying HTML format...")
      html_file <- file.path(output_dir, "item_bank_analysis.html")
      result_file <- rmarkdown::render(
        input = temp_md,
        output_format = "html_document",
        output_file = basename(html_file),
        output_dir = output_dir,
        quiet = FALSE
      )
      
      if (file.exists(result_file)) {
        message("HTML report saved to: ", result_file)
      } else {
        warning("HTML file generation may have failed")
      }
    }
  })
  
  # Clean up
  file.remove(temp_md)
  
  # Also display in console
  safe_cat(Agent_poolAnalysis$response$choices[[1]]$message$content)
  safe_cat("\n")
  safe_cat("Here are the detailed areas needing more items:\n")
  print(areasNeedItems)
  
  # Return output file path if it exists
  result_path <- file.path(output_dir, paste0("item_bank_analysis.", output_format))
  if (file.exists(result_path)) {
    return(result_path)
  } else if (output_format == "pdf" && file.exists(file.path(output_dir, "item_bank_analysis.html"))) {
    return(file.path(output_dir, "item_bank_analysis.html"))
  } else {
    warning("Could not find generated report file")
    return(NULL)
  }
}


areasNeedItems<-itembankCheck(item_bank)[[1]]

# py_install("openai")    # Install the package if it's the first time running this script
poolAnalysis <- agentExecute(py_file='Agent_poolAnalysis.py', max_retries = 5,ModelInfo=ModelInfo)
report_poolAnalysis(poolAnalysis, areasNeedItems, "html")
