library(psych)
library(ShinyItemAnalysis)
script_path <- dirname(rstudioapi::getSourceEditorContext()$path)
setwd(script_path)
source("global.R")
use_condaenv_from_file("py_env.txt")

#Please enter IDs of the pilot items
pilotItemID<-c("PBM_20240905_3928219eabe229d99cd72289377e67944c8e919b5fca6394305c13cd44d850b1",
               "PBM_20240906_4928219eabe229d99cd72289377e67944c8e919b5fca6394305c13cd44d850b1",
               "PBM_20240907_5928219eabe229d99cd72289377e67944c8e919b5fca6394305c13cd44d850b1",
               "PBM_20240908_6928219eabe229d99cd72289377e67944c8e919b5fca6394305c13cd44d850b1")			
#Read the csv files containing responses and keys
pilotResponse<-read.csv("pilotResponse.csv",header=T)
pilotKey<-read.csv("pilotKey.csv",header=T)
pilotData<-convert_to_binary(pilotResponse,pilotKey)
#Select the chunk of pilot items
pilotResponse_pilotItemOnly<-pilotResponse[,names(pilotResponse)%in%pilotItemID]
pilotKey_pilotItemOnly<-pilotKey[,names(pilotKey)%in%pilotItemID]
pilotData_pilotItemOnly<-convert_to_binary(pilotResponse_pilotItemOnly,pilotKey_pilotItemOnly)
pilotData_pilotItemOnly
#Start item analyses
##traditional item analysis table
tradItemAnalysis_pilotItemOnly<-ItemAnalysis(pilotData)[rownames(ItemAnalysis(pilotData))%in%pilotItemID,]
tradItemAnalysis_pilotItemOnly<-tradItemAnalysis_pilotItemOnly[,colnames(tradItemAnalysis_pilotItemOnly)%in%c("Difficulty",'Mean','SD','RIR','RIT')]
tradItemAnalysis_pilotItemOnly
##distractor analysis
distractorAnalysis_pilotItemOnly<-DistractorAnalysis(pilotResponse, pilotKey, item =which(names(pilotKey)%in%pilotItemID), num.groups = 3, p.table = TRUE)
for(i in 1:length(distractorAnalysis_pilotItemOnly)){
  colnames(distractorAnalysis_pilotItemOnly[[i]])<-c("poor","mid","good")

  rownames(distractorAnalysis_pilotItemOnly[[i]])[which(rownames(distractorAnalysis_pilotItemOnly[[i]])!=as.character(pilotKey_pilotItemOnly[i]))]<-paste(
    rownames(distractorAnalysis_pilotItemOnly[[i]])[which(rownames(distractorAnalysis_pilotItemOnly[[i]])!=as.character(pilotKey_pilotItemOnly[i]))],
    "(distractor)",sep=''
  )
  
  rownames(distractorAnalysis_pilotItemOnly[[i]])[which(rownames(distractorAnalysis_pilotItemOnly[[i]])==as.character(pilotKey_pilotItemOnly[i]))]<-paste(
    rownames(distractorAnalysis_pilotItemOnly[[i]])[which(rownames(distractorAnalysis_pilotItemOnly[[i]])==as.character(pilotKey_pilotItemOnly[i]))],
    "(key)",sep=''
  )
}
distractorAnalysis_pilotItemOnly

sink("temp_itemAnalysis.txt")
print(pilotItemID)
cat(".") 
cat("These items' difficulty estimate(i.e., mean), standard deviation(SD),item-rest correlation (RIR), as well as item-test correlation (RIT) are presented below:")
cat(" ") 
print(tradItemAnalysis_pilotItemOnly)
cat(" ")
cat("These items' distractor analyses are presented below, where #1 the test takers overall performance are grouped to 'poor','mid', and'good' according to their total scores and #2 the options including key and distractors are marked:")
cat(" ") 
print(distractorAnalysis_pilotItemOnly)
sink() 



##difficulty and discrimination plot
agentExecute(py_file='Agent_itemAnalysis.py', max_retries = 10,ModelInfo=ModelInfo[1,],wrongJson=F)
Agent_itemAnalysis<-tempOrganizeJson

py_run_file("Converter.py")
itemAnalysis_content <- py$convert_to_html(Agent_itemAnalysis)
html_current_date <- format(Sys.Date(), "%Y-%m-%d")
# Add level 1 heading and date before HTML content
final_itemAnalysis_html_content <- paste0(
  "<h1>Item Analysis Report</h1>",  # Level 1 heading
  "<p>Date: ", html_current_date, "</p>",  # Date
  "<hr>",  # Add a horizontal line (optional)
  itemAnalysis_content  # Original HTML content
)

# Write final HTML content to file
writeLines(final_itemAnalysis_html_content, "item_Analysis_report.html")

# Print generated HTML file path
print(paste("Item_Analysis HTML file saved as:", getwd(), "/item_Analysis_report.html", sep=""))
browseURL("item_Analysis_report.html")
