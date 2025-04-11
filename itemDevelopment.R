#Default path of the function
script_path <- dirname(rstudioapi::getSourceEditorContext()$path)
setwd(script_path)

library(jsonlite)
library(reticulate)
library(digest)
library(stringr)
library(markdown)
source("global.R")
source("poolAnalysis.R")

workingLanguage("English")
##Illustrate the first inquiry from the waiting list(i.e.,the areasNeedItems)
assignment<-areasNeedItems[5,]
assignment
################################################
################################################
#Item writing by agents simulating item writers
################################################
################################################
poolAnalysisPrompt<-function(x){
  (toJSON(x, pretty = TRUE, auto_unbox = TRUE))
}
#Customize prompt for each item on the waiting list
temp_itemNeeded<-poolAnalysisPrompt(assignment)
temp_itemNeededID<-assignTempItemID(temp_itemNeeded)

#Construct complete item writing prompts
write.table(temp_itemNeeded, file = "temp_itemNeeded.txt", sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)

# Use python to execute the 
# Agent_itemWriting_Step1 <- agentExecute(py_file='Agent_itemWriting.py', max_retries = 10,ModelInfo=ModelInfo,wrongJson=T)
# Agent_itemWriting_Step1 <- Agent_itemWriting_Step1$response$choices[[1]]$message$content
# first_attempt <- tempOrganizeJson
# rm(tempOrganizeJson)

Agent_itemWriting_Step1 <- agentExecute(py_file='Agent_itemWriting_image.py', max_retries = 10,ModelInfo=ModelInfo,wrongJson=T, requireJson = T)
Agent_itemWriting_Step1 <- Agent_itemWriting_Step1$response$choices[[1]]$message$content
first_attempt <- tempOrganizeJson
rm(tempOrganizeJson)


#Save the raw output from LLM to a txt
sink(paste(temp_itemNeededID,".txt",sep=''))
cat("##############################", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("version#","1", sep = " ", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemWriting_Step1)
cat("\n", append = TRUE)
cat("id:", sep = " ", append = TRUE)
safe_cat(temp_itemNeededID)
cat("\n", append = TRUE)
cat("disciplines :",append = TRUE)
safe_cat(as.character(assignment[1]$disciplines))
cat("\n", append = TRUE)
cat("systems :",append = TRUE)
safe_cat(as.character(assignment[2]$systems))
cat("\n", append = TRUE)
cat("competencies :",append = TRUE)
safe_cat(as.character(assignment[3]$competencies))
cat("\n", append = TRUE)
cat("last_edit_by:","author", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("is_final:","F", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("comment:","Initial Creation", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("##############################", sep = " ", append = TRUE)
cat("\n", append = TRUE)
sink() 

#Save the output to a json entity and update the itemDataBase
ready_for_fill_Item<-emptyItemClass
ready_for_fill_Item$id<-temp_itemNeededID
ready_for_fill_Item$disciplines<-(as.character(assignment[1]$disciplines))
ready_for_fill_Item$systems<-(as.character(assignment[2]$systems))
ready_for_fill_Item$competencies<-(as.character(assignment[3]$competencies))
ready_for_fill_Item$question<-first_attempt$question
ready_for_fill_Item$options<-first_attempt$options
ready_for_fill_Item$correct_answer<-first_attempt$correct_answer
ready_for_fill_Item$last_edit_by<-'author'
ready_for_fill_Item$is_final<-FALSE
ready_for_fill_Item$comment<-"Initial Creation"
write_json(first_attempt, "temp_editNeeded.txt", pretty = TRUE)
itemDataBase[[length(itemDataBase)+1]]<-ready_for_fill_Item

################################################
################################################
#Initial item editing by NBME editorial staff agents
################################################
################################################
ModelInfo_differentReviewers<-ModelInfo[sample(nrow(ModelInfo),3),]

# Reviewer 1
Agent_itemEditing_Step2_Reviewer1 <- agentExecute(py_file='Agent_itemEditing_Reviewer1.py', max_retries = 10, ModelInfo=ModelInfo_differentReviewers[1,], wrongJson=T)
Agent_itemEditing_Step2_Reviewer1 <- Agent_itemEditing_Step2_Reviewer1$response$choices[[1]]$message$content
# Reviewer 2
Agent_itemEditing_Step2_Reviewer2 <- agentExecute(py_file='Agent_itemEditing_Reviewer2.py', max_retries = 10, ModelInfo=ModelInfo_differentReviewers[2,], wrongJson=T)
Agent_itemEditing_Step2_Reviewer2 <- Agent_itemEditing_Step2_Reviewer2$response$choices[[1]]$message$content
# Reviewer 3
Agent_itemEditing_Step2_Reviewer3 <- agentExecute(py_file='Agent_itemEditing_Reviewer3.py', max_retries = 10, ModelInfo=ModelInfo_differentReviewers[3,], wrongJson=T)
Agent_itemEditing_Step2_Reviewer3 <- Agent_itemEditing_Step2_Reviewer3$response$choices[[1]]$message$content



sink("temp_commentNeeded.txt")
cat('<The USMLE Step1 item draft developed by the author>', append = TRUE)
cat("\n", append = TRUE)
safe_cat(ready_for_fill_Item)
cat('</The USMLE Step1 item draft developed by the author>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('<Suggestions from editorial staff#1>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemEditing_Step2_Reviewer1)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('</Suggestions from editorial staff#1>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('<Suggestions from editorial staff#2>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemEditing_Step2_Reviewer2)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('</Suggestions from editorial staff#2>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('<Suggestions from editorial staff#3>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemEditing_Step2_Reviewer3)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('</Suggestions from editorial staff#3>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
sink() 


#Save the raw output from LLM to a txt
sink(paste(temp_itemNeededID,".txt",sep=''),append = TRUE)
cat("\n", append = TRUE)
cat("##############################", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("Suggestions for version#","1", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('<Suggestions from editorial staff#1>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemEditing_Step2_Reviewer1)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('</Suggestions from editorial staff#1>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('<Suggestions from editorial staff#2>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemEditing_Step2_Reviewer2)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('</Suggestions from editorial staff#2>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('<Suggestions from editorial staff#3>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemEditing_Step2_Reviewer3)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat('</Suggestions from editorial staff#3>', append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat("\n", append = TRUE)
cat("##############################", sep = " ", append = TRUE)
cat("\n", append = TRUE)
sink() 


################################################
################################################
#Initial changes by the authors 
################################################
################################################
temp_suggestions<-c(Agent_itemEditing_Step2_Reviewer1,
                    Agent_itemEditing_Step2_Reviewer2,
                    Agent_itemEditing_Step2_Reviewer3)
replace_api_info('Agent_itemRevising.py',ModelInfo)
Agent_itemRevising_Step3 <- agentExecute(py_file='Agent_itemRevising.py', max_retries = 10,ModelInfo=ModelInfo,wrongJson=T, requireJson = T)
Agent_itemRevising_Step3 <- Agent_itemRevising_Step3$response$choices[[1]]$message$content
second_writing <- tempOrganizeJson
rm(tempOrganizeJson)

#Save the output to a json entity and update the itemDataBase
ready_for_fill_Item<-emptyItemClass
ready_for_fill_Item$id<-temp_itemNeededID
ready_for_fill_Item$disciplines<-(as.character(assignment[1]$disciplines))
ready_for_fill_Item$systems<-(as.character(assignment[2]$systems))
ready_for_fill_Item$competencies<-(as.character(assignment[3]$competencies))
ready_for_fill_Item$question<-second_writing$question
ready_for_fill_Item$options<-second_writing$options
ready_for_fill_Item$correct_answer<-second_writing$correct_answer
ready_for_fill_Item$last_edit_by<-'author'
ready_for_fill_Item$is_final<-FALSE
ready_for_fill_Item$comment<-paste(paste("Comments&Suggestions from three staff members: ",temp_suggestions,collapse = ''),
                                   paste("Responses:",second_writing$comment),
                                   sep = "\n ")
ready_for_fill_Item$version<-ready_for_fill_Item$version+1

#Save the raw output from LLM to a txt
sink(paste(temp_itemNeededID,".txt",sep=''),append = TRUE)
cat("\n", append = TRUE)
cat("##############################", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("version#","2", sep = " ", append = TRUE)
cat("\n", append = TRUE)
safe_cat(Agent_itemRevising_Step3)
cat("\n", append = TRUE)
cat("id: ", sep = " ", append = TRUE)
safe_cat(temp_itemNeededID)
cat("\n", append = TRUE)
cat("disciplines: ",append = TRUE)
safe_cat(as.character(assignment[1]$disciplines))
cat("\n", append = TRUE)
cat("systems: ",append = TRUE)
safe_cat(as.character(assignment[2]$systems))
cat("\n", append = TRUE)
cat("competencies: ",append = TRUE)
safe_cat(as.character(assignment[3]$competencies))
cat("\n", append = TRUE)
cat("last_edit_by:","author", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("is_final:","F", sep = " ", append = TRUE)
cat("\n", append = TRUE)
cat("comment: ", append = TRUE)
safe_cat(unlist(second_writing$comment))
cat("\n", append = TRUE)
cat("##############################", sep = " ", append = TRUE)
cat("\n", append = TRUE)
sink() 


################################################
################################################
#Second item editing by NBME editorial staff agents 
################################################
################################################
#Save the raw output from LLM to a txt
cat(readLines(paste(temp_itemNeededID,".txt",sep='')), file = "temp_postrevisionNeeded.txt", sep = "\n")

#Get agent to work 
Agent_itemReediting_Step4 <- agentExecute(py_file='Agent_itemReediting.py', max_retries = 10,ModelInfo=ModelInfo,wrongJson=T, requireJson = T)
Agent_itemReediting_Step4 <- Agent_itemReediting_Step4$response$choices[[1]]$message$content
second_review <- tempOrganizeJson
rm(tempOrganizeJson)

################################################
################################################
#Check to see if further revisions are demanded 
################################################
################################################
if(second_review$is_final){
  ready_for_fill_Item$is_final<-TRUE
  itemDataBase[[length(itemDataBase)+1]]<-ready_for_fill_Item
  final_writing <- second_writing
  
  sink(paste(temp_itemNeededID,".txt",sep=''),append = TRUE)
  cat("\n", append = TRUE)
  cat("The final version", append = TRUE)
  print(ready_for_fill_Item)
  cat("\n", append = TRUE)
  sink() 
} else {
  #Save the new changes/comments to the history of the item
  sink(paste(temp_itemNeededID,".txt",sep=''),append = TRUE)
  cat("##############################", sep = " ", append = TRUE)
  cat("\n", append = TRUE)
  cat("Comments for version#","2", sep = " ", append = TRUE)
  cat("\n", append = TRUE)
  cat("is_final:", append = TRUE)
  safe_cat(unlist(second_review[1]))
  cat("\n", append = TRUE)
  cat("comment: ", append = TRUE)
  safe_cat(unlist(second_review[2]))
  cat("\n", append = TRUE)
  cat("my_suggested_revision: ", append = TRUE)
  cat("\n", append = TRUE)
  safe_cat(unlist(second_review[3]))
  cat("\n", append = TRUE)
  cat("##############################", sep = " ", append = TRUE)
  cat("\n", append = TRUE)
  sink() 
  
  # Read the original txt file content
  txt_content <- readLines(paste(temp_itemNeededID,".txt",sep=''))
  # Find the position of version# 2
  version2_pos <- grep("version# 2", txt_content)[1]
  # Extract content from version# 2 to the end of file
  extracted_content <- txt_content[version2_pos:length(txt_content)]
  # Write extracted content to new file
  writeLines(extracted_content, "temp_editorialVersionNeeded.txt")
  
  #The author reads the comment from the second review and respond to give the final item
  Agent_itemFinalwriting_Step5 <- agentExecute(py_file='Agent_itemFinalwriting.py',max_retries = 10,ModelInfo=ModelInfo,wrongJson=T, requireJson = T)
  Agent_itemFinalwriting_Step5 <- Agent_itemFinalwriting_Step5$response$choices[[1]]$message$content
  thrid_revision <-tempOrganizeJson
  rm(tempOrganizeJson)
  final_writing <- thrid_revision
  
  #The finalized item is recorded to item's history text
  sink(paste(temp_itemNeededID,".txt",sep=''),append = TRUE)
  cat("##############################", sep = " ", append = TRUE)
  cat("\n", append = TRUE)
  cat("Comments for version#","3", sep = " ", append = TRUE)
  cat("\n", append = TRUE)
  cat("is_final: T", append = TRUE)
  cat("\n", append = TRUE)
  cat("final_revision: ", append = TRUE)
  cat("\n", append = TRUE)
  safe_cat(unlist(thrid_revision))
  cat("\n", append = TRUE)
  cat("##############################", sep = " ", append = TRUE)
  cat("\n", append = TRUE)
  sink() 
  
  #Save the output to a json entity and update the itemDataBase
  ready_for_fill_Item<-emptyItemClass
  ready_for_fill_Item$id<-temp_itemNeededID
  ready_for_fill_Item$disciplines<-(as.character(assignment[1]$disciplines))
  ready_for_fill_Item$systems<-(as.character(assignment[2]$systems))
  ready_for_fill_Item$competencies<-(as.character(assignment[3]$competencies))
  ready_for_fill_Item$question<-thrid_revision$question
  ready_for_fill_Item$options<-thrid_revision$options
  ready_for_fill_Item$correct_answer<-thrid_revision$correct_answer
  ready_for_fill_Item$last_edit_by<-'author'
  ready_for_fill_Item$is_final<-TRUE
  ready_for_fill_Item$comment<-paste(paste("Comments&Suggestions from a staff member in the second review: ",paste(names(second_review), second_review, sep = ": ", collapse = "\n"),collapse = ''),
                                     paste("Responses:",thrid_revision$comment),
                                     sep = "\n ")
  ready_for_fill_Item$version<-ready_for_fill_Item$version+2
  itemDataBase[[length(itemDataBase)+1]]<-ready_for_fill_Item
}

################################################
################################################
#image generation if needed
################################################
################################################
# Only execute image generation and verification when final_writing$image_needed is TRUE
if(isTRUE(final_writing$image_needed)) {
  # py_install("google-genai")
  py_run_file("Agent_image_gen.py")

  # If using online API to generate medical images
  replace_api_info('Agent_image_gen.py', ModelInfo_image)
  image_path <- py$generate_medical_image_with_api(final_writing$image_needed, 
                                          final_writing$image_type,
                                          final_writing$image_prompt, 
                                          "H:/medical image")

  # If using local model to generate medical images
  image_path <- py$generate_medical_image(final_writing$image_needed, 
                                          final_writing$image_type,
                                          final_writing$image_prompt, 
                                          "G:/Download/VM/RunMINIM/model", 
                                          "H:/medical image")
  
  py_run_file("Agent_image_verification.py")
  # Call Python function to verify image
  image_image_verification <- py$verify_medical_image(image_path, final_writing, script_path)

  # Check verification results
  image_verification_json <- fromJSON(image_image_verification)
  verification_result <- if(
      image_verification_json$answer_evaluation$professional_answer$image_dependency$is_image_dependent && 
      image_verification_json$is_model_answer_correct && 
      image_verification_json$consistency_evaluation$consistency_evaluation$verdict == "consistent"
    ) {
    print("Image verification passed")
  } else {
    print("Image requires manual review for authenticity")
  }

  # Add verification result to verification object
  image_verification_json$verification_summary <- verification_result
  image_image_verification <- toJSON(image_verification_json, auto_unbox = TRUE, pretty = TRUE)
} else {
  # If not needed, set the variable to NULL
  image_path <- NULL
  image_image_verification <- NULL
  image_verification_json <- NULL
}




py_run_file("Converter.py")
# Call Python function to convert content to HTML
processed_step1 <- py$convert_to_html(Agent_itemWriting_Step1)
processed_reviewer1 <- py$convert_to_html(Agent_itemEditing_Step2_Reviewer1)
processed_reviewer2 <- py$convert_to_html(Agent_itemEditing_Step2_Reviewer2)
processed_reviewer3 <- py$convert_to_html(Agent_itemEditing_Step2_Reviewer3)
processed_step3 <- py$convert_to_html(Agent_itemRevising_Step3)
processed_step4 <- py$convert_to_html(Agent_itemReediting_Step4)
# If step5 exists, process it
processed_step5 <- NULL
if(exists("Agent_itemFinalwriting_Step5")) {
  processed_step5 <- py$convert_to_html(Agent_itemFinalwriting_Step5)
}

# Combine the processed content into a single HTML
final_html <- paste(
  "<html><head><title>Item Development Report</title>
  <style>
    .item-id {
      color: #808080;
      font-size: 1.5em;
      text-align: center;
    }
  </style></head><body>",
  sprintf("<h1 style='text-align: center;'>Item Development Report</h1>
  <div class='item-id'>%s</div>", temp_itemNeededID),
  "<hr>",
  "<h2>Step 1: Writing</h2>", processed_step1,
  "<hr>",
  "<h2>Step 2: Editing - Reviewer 1</h2>", processed_reviewer1,
  "<hr>",
  "<h2>Step 2: Editing - Reviewer 2</h2>", processed_reviewer2,
  "<hr>",
  "<h2>Step 2: Editing - Reviewer 3</h2>", processed_reviewer3,
  "<hr>",
  "<h2>Step 3: Revising</h2>", processed_step3,
  "<hr>",
  "<h2>Step 4: Reediting</h2>", processed_step4,
  if(!is.null(processed_step5)) paste("<hr>", "<h2>Step 5: Final Revision</h2>", processed_step5, sep="") else "",
  "</body></html>"
)

# Add generated image to final_html if it exists
if(!is.null(image_path) && file.exists(image_path)) {
  # Read image file and convert to base64
  image_data <- base64enc::base64encode(image_path)
  
  # Convert image verification result to HTML
  processed_verification <- py$convert_to_html(image_image_verification)
  
  # Construct image HTML tag with verification results
  image_html <- sprintf(' <hr>
                          <div class="medical-image">
                          <h2>Generated Medical Image</h2>
                          <img src="data:image/png;base64,%s" alt="Generated Medical Image">
                          <p class="image-caption">%s</p>
                          <div class="image-verification">
                            <h3>Image Verification Results</h3>
                            %s
                          </div>
                        </div>', 
                        image_data,
                        ifelse(!is.null(final_writing$image_prompt), 
                               paste("Description:", final_writing$image_prompt), 
                               "Generated Medical Image"),
                        processed_verification)
  
  # Ensure only the last </body> tag is replaced
  body_close_pos <- tail(gregexpr("</body>", final_html)[[1]], 1)
  if(body_close_pos > 0) {
    final_html <- paste0(
      substr(final_html, 1, body_close_pos-1),
      image_html,
      substr(final_html, body_close_pos, nchar(final_html))
    )
  }
}

# Write the final HTML to a file
writeLines(final_html, paste0("Item_Development_for_", temp_itemNeededID, ".html"))

# Open the result in a browser
browseURL(paste0("Item_Development_for_", temp_itemNeededID, ".html"))



delete_temp_files <- function(directory = ".") {
  # List all files in the specified directory that start with "temp"
  temp_files <- list.files(path = directory, pattern = "^temp", full.names = TRUE)
  
  # Check if there are any files to delete
  if (length(temp_files) == 0) {
    message("No files starting with 'temp' found in the directory.")
    return(invisible(NULL))
  }
  
  # Delete the files
  file.remove(temp_files)
  
  # Print a message indicating the files that were deleted
  message("Deleted the following files: ", paste(temp_files, collapse = ", "))
}

# Example usage
delete_temp_files()

