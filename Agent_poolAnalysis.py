fixPrompt_content = "You are working at NBME USMLE item development department. Your job is about analyzing item bank and providing the areas needing more items. There are some information below that you can check and tell us the overall situation of the item bank as well as provide the relavant instruction about the item development tasks"

with open(r'C:/Users/Feng/Desktop/AgentItemDev/currentItembankInfo.json', 'r', encoding='utf-8') as file:
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
