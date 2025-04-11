#Default path of the function
script_path <- dirname(rstudioapi::getSourceEditorContext()$path)
setwd(script_path)

library(jsonlite)
library(reticulate)
library(digest)
library(stringr)

use_condaenv_from_file <- function(file_path) {
  env_name <- readLines(file_path, warn = FALSE)
  env_name <- trimws(env_name)
  if (length(env_name) == 0) {
    stop("Failed to read the environment name from the file")
  }
  reticulate::use_condaenv(env_name)
  cat("Using conda environment:", env_name, "\n")
}




################################################
################################################
#Start: Some Pre-defined functions needing for the work flow
################################################
################################################

ModelInfo<-read.csv("ModelInfo.csv",header = T)
# Filter out rows where type is "image"
ModelInfo_image <- ModelInfo[ModelInfo$type == "image", ]
ModelInfo <- ModelInfo[ModelInfo$type != "image", ]

#Randomly select a model to execute the agent work
replace_api_info <- function(pyName, ModelInfo=ModelInfo) {
  file_path<-paste(paste(getwd(),"/",sep=''),pyName,sep='')
  #read file
  text <- readLines(file_path, warn = FALSE)
  text <- paste(text, collapse = "\n")  
  random_row <- sample(nrow(ModelInfo), 1)
  #copy api and key
  new_api_key <- ModelInfo$api_key[random_row]
  new_base_url <- ModelInfo$base_url[random_row]
  new_model <- ModelInfo$model[random_row]
  #replacment
  text <- gsub('api_key="[^"]+"', paste0('api_key="', new_api_key, '"'), text)
  text <- gsub('base_url="[^"]+"', paste0('base_url="', new_base_url, '"'), text)
  text <- gsub('model="[^"]+"', paste0('model="', new_model, '"'), text)
  writeLines(text,file_path)
}



#Assign an Id to a item-developing task
assignTempItemID <- function(json_object) {
  # Parse the JSON object
  parsed_json <- fromJSON(json_object, simplifyVector = TRUE)
  # Extract the first letter of each value
  first_letters <- sapply(parsed_json, function(value) {
    substr(value, 1, 1)
  })
  # Define a regular expression pattern for punctuation
  punctuation_pattern <- "[[:punct:]]"
  # Use gsub to replace punctuation with an empty string
  cleaned_date <- gsub(punctuation_pattern, "", Sys.Date())
  # Combine the first letters into a single string
  result <- paste(paste(first_letters, collapse = ""),cleaned_date,sep='_')
  result <- paste(result,digest(Sys.time(), algo = "sha256"),sep='_')
  result
}

#A database of items where their histories are documented 
itemDataBase <- list()

emptyItemClass<-list(
  id = "XXXX",
  disciplines = "XXXX",
  systems = "XXXX",
  competencies = "XXXX",
  question = "XXXX",
  options = NULL,
  correct_answer = "XXXX",
  Explanation = "XXXX",
  Rationale_for_excluding_other_options = "XXXX",
  Key_Learning_Points = "XXXX",
  image_needed = "XXXX",
  image_type = "XXXX",
  image_prompt = "XXXX",
  last_edit_by = "XXXX",
  is_final = F,
  version= 1,
  comment='XXXX'
)
#cat_output<-(str_replace_all((Agent_itemReediting_Step4$response$choices[[1]]$message$content), fixed("*"), ""))

#To avoid cat problems (like matrix and list can't be cat)
safe_cat <- function(x,append) {
  tryCatch(
    {
      cat(x,sep,append)
    },
    error = function(e) {
      print(x)
    }
  )
}


#Clean and save print output to a json entity 
organizeJson<-function(cat_output,wrongJson=T){
  clean_output <- gsub("```json", "", cat_output)
  clean_output <- gsub("```", "", clean_output)
  # Trim leading and trailing whitespace
  clean_output <- trimws(clean_output)
  
  if(wrongJson){
    # Find the positions of the first "{" and the last "}"
    first_open_brace <- regexpr("\\{", clean_output)
    last_close_brace <- rev(gregexpr("\\}", clean_output)[[1]])[1]
    
    # Extract the content between the first "{" and the last "}"
    if (first_open_brace > 0 && last_close_brace > 0) {
      clean_output <- substr(clean_output, first_open_brace, last_close_brace)
    } else {
      return(NULL)
    }
    clean_output<-str_replace_all(clean_output, fixed("*"), "")
    # Remove newline characters
    clean_output <- gsub("\n", "", clean_output)
    
    # Remove extra spaces
    clean_output <- gsub("\\s+", " ", clean_output)
    
    # Parse the cleaned JSON string into an R object
    json_object <- fromJSON(clean_output, simplifyVector = TRUE)
    json_object
  }else{
    clean_output
  }
  
  
}

#Minize the unstable generations of LLM
try_functions <- function(cat_output) {
  # Try the first function
  result <- tryCatch({
    names(organizeJson(cat_output))
  }, error = function(e) {
    return(NULL)
  })
  # If the result is NULL, try the next function
  if (is.null(result)) {
    result <- tryCatch({
      names(organizeJson(cat_output)[[1]])
      
      
    }, error = function(e) {
      temp_jsonOut<-organizeJson(cat_output)[[1]]
      names(temp_jsonOut)<-c("question","options","correct_answer")
      return(temp_jsonOut)
    })
  }
  # If the result is still NULL, try the next function
  if (is.null(result)) {
    result <- tryCatch({
      fun2()
    }, error = function(e) {
      return(NULL)
    })
  }
  # If the result is still NULL, try the last function
  if (is.null(result)) {
    result <- tryCatch({
      fun3()
    }, error = function(e) {
      return(NULL)
    })
  }
  return(result)
}

# Internal function to replace file paths in Python files
replace_file_paths_internal <- function(py_file, script_path) {
  # Read Python file content
  file_path <- file.path(getwd(), py_file)
  lines <- readLines(file_path, warn = FALSE)
  
  # Find lines containing open function
  for (i in seq_along(lines)) {
    # Check if the line contains file opening operation
    if (grepl("open\\(r['\"].*['\"]", lines[i])) {
      # Extract file path part
      file_path_match <- regmatches(lines[i], regexpr("open\\(r['\"].*?['\"]", lines[i]))
      
      if (length(file_path_match) > 0) {
        # Extract original file path
        orig_path <- gsub("open\\(r['\"]|['\"]$", "", file_path_match)
        
        # Get file name
        file_name <- basename(orig_path)
        
        # Build new path
        new_path <- file.path(script_path, file_name)
        
        # Replace path in the line
        quote_char <- ifelse(grepl("'", file_path_match), "'", "\"")
        new_open_statement <- paste0("open(r", quote_char, new_path, quote_char)
        lines[i] <- gsub("open\\(r['\"].*?['\"]", new_open_statement, lines[i])
      }
    }
  }
  
  # Write back to file
  writeLines(lines, file.path(getwd(), py_file))
  
  message("File paths updated to: ", script_path)
}

# Initiate agent creation and execute a pre-defined .py file
agentExecute <- function(py_file, max_retries = 10, ModelInfo = ModelInfo, wrongJson = TRUE, script_path = NULL, requireJson = FALSE) {
  # If script path is not provided, get the current script path
  if (is.null(script_path)) {
    tryCatch({
      script_path <- dirname(rstudioapi::getSourceEditorContext()$path)
      setwd(script_path)
    }, error = function(e) {
      script_path <- getwd()
      message("Unable to get current script path. Using current working directory: ", script_path)
    })
  }
  
  # Replace file paths in the Python file
  replace_file_paths_internal(py_file, script_path)
  
  result <- NULL  # Initialize result variable
  json_found <- FALSE  # Flag to track if valid JSON was found
  
  for (i in 1:max_retries) {
    tryCatch({
      # Randomly assign an LLM to the agent
      replace_api_info(py_file, ModelInfo)
      # Execute the request sent to the agent
      tempAgentfeedback <- py_run_file(py_file)  # Use local variable
      # Check if the API result is valid
      content_length <- nchar(tempAgentfeedback$response$choices[[1]]$message$content)
      
      # Check if the output content has fewer than 30 words
      word_count <- length(strsplit(tempAgentfeedback$response$choices[[1]]$message$content, "\\s+")[[1]])
      
      if (content_length > 5 && word_count >= 30) {
        # Process the JSON content
        temp_json <- organizeJson(tempAgentfeedback$response$choices[[1]]$message$content, wrongJson)
        tempOrganizeJson <<- temp_json  # Keep the global assignment for backward compatibility
        
        # Check if JSON is required and if it was successfully extracted
        if (requireJson && (is.null(temp_json) || (is.list(temp_json) && length(temp_json) == 0))) {
          message("No valid JSON found in response. Retrying... (Attempt ", i, ")")
          next  # Skip to next iteration
        }
        
        result <- tempAgentfeedback  # Save result to local variable
        json_found <- TRUE  # Set flag to indicate JSON was found
        # If execution is successful, break out of the loop
        break
      } else {
        message("Response content is too short. Retrying...")
      }
      
    }, error = function(e) {
      message("Error occurred: ", e$message)
    })
  }
  
  if (i == max_retries) {
    if (requireJson && !json_found) {
      stop("Failed to get valid JSON response after ", max_retries, " retries.")
    } else {
      stop("Failed to execute commands successfully after ", max_retries, " retries.")
    }
  } else {
    message("Execution successful after ", i, " retries.")
  }
  
  return(result)  # Return the result instead of modifying a global variable
}


convert_to_binary <- function(original_data, answer_key) {
  binary_result <- matrix(0, nrow = nrow(original_data), ncol = ncol(original_data))
  for (i in 1:nrow(original_data)) {
    for (j in 1:ncol(original_data)) {
      if (original_data[i, j] == answer_key[j]) {
        binary_result[i, j] <- 1
      }
    }
  }
  binary_result<-as.data.frame(binary_result)
  colnames(binary_result)<-colnames(original_data)
  return(binary_result)
}


workingLanguage <- function(new_language) {
  # Check input parameter
  if (!is.character(new_language) || length(new_language) != 1) {
    stop("new_language must be a single string")
  }
  
  # Build file path
  file_path <- file.path(script_path, "language_setting.txt")
  
  # Check if file exists
  if (!file.exists(file_path)) {
    stop("Language setting file not found: ", file_path)
  }
  
  # Read and update file content
  tryCatch({
    # Read file content
    content <- readLines(file_path, warn = FALSE)
    
    if (length(content) == 0) {
      stop("Language setting file is empty")
    }
    
    # Use regex to replace content in brackets
    updated_content <- gsub("\\[.*?\\]", paste0("[", new_language, "]"), content)
    
    # Check if there are actual changes
    if (identical(content, updated_content)) {
      message("Language setting unchanged: ", new_language)
      return(invisible(FALSE))
    }
    
    # Write updated content back to file
    writeLines(updated_content, file_path)
    
    # Return success message
    message(sprintf("Language successfully updated to: %s", new_language))
    return(invisible(TRUE))
    
  }, error = function(e) {
    stop("Error occurred while updating language setting: ", e$message)
  })
}

# Usage example
# workingLanguage("Chinese")
# workingLanguage("English")

################################################
################################################
#End: Some Pre-defined functions needing for the work flow
################################################
################################################
