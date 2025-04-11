fixPrompt_content = "As an psychometric expert analyzing the quality of USMLE Step1 test items, you have received results after administrations for some newly-developed items. Accordingly, you should use the analytical results to investigate the quality of each item of interest. If there are any improvements demanded, you should point out the specific areas (e.g., certain distractors need to be revised or some item's difficulty as well as discrimination is not sufficient). The IDs of the items are listed below"


with open(r'C:/Users/Feng/Desktop/AgentItemDev/temp_itemAnalysis.txt ', 'r', encoding='utf-8') as file:
    # Read the contents of the file
    specificPrompt_content = file.read()

with open(r'C:/Users/Feng/Desktop/AgentItemDev/language_setting.txt', 'r', encoding='utf-8') as file:
    # Read the contents of the file
    language_prompt = file.read() 
 
from openai import OpenAI
api_key="xxx"
base_url="xxx"
client = OpenAI(api_key=api_key, base_url=base_url)

response = client.chat.completions.create(
    model="xxx",
    messages=[
        {"role": "system", "content": language_prompt + "\n" + fixPrompt_content},
        {"role": "user", "content": specificPrompt_content  },
    ],
    stream=False
)
print(response.choices[0].message.content)
