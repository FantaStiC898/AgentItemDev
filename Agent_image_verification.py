

import pandas as pd
import os
import json
from openai import OpenAI

system_prompt_answer = """You are an experienced medical imaging expert analyzing medical test questions. Your tasks are:
1. Carefully examine the provided medical image
2. Read the associated test question and image
3. Provide a detailed, professional answer based on the image content and test question requirements
4. Analyze whether the question could be answered without the image

Focus specifically on:
- Precise interpretation of imaging findings
- Accurate medical terminology usage
- Correlation between visual evidence and clinical information
- Clear presentation of diagnostic reasoning
- Assessment of whether the question is image-dependent or could be answered from text alone

Deliver a comprehensive response that demonstrates clinical expertise and image analysis skills.

Output requirements:
```json
{
    "professional_answer": {
        "selected_option": "A/B/C/D/E",
        "image_interpretation": "Structured description of findings",
        "diagnostic_considerations": ["Differential diagnosis list"],
        "key_observations": ["List of significant visual features"],
        "clinical_correlation": "Connection between image findings and clinical presentation",
        "conclusion": "Definitive/probable diagnosis",
        "image_dependency": {
            "is_image_dependent": true/false,
            "reasoning": "Explanation of why the question requires or doesn't require the image"
        }
    }
}
"""



system_prompt_consistency = """You are a medical image quality control specialist. Your tasks are:
1. Thoroughly inspect the provided medical image
2. Analyze the accompanying description (image_prompt)
3. Evaluate whether the image content matches the textual description

Assessment criteria:
- Anatomical accuracy
- Pathological presentation
- Technical parameters (modality, view, orientation)
- Clinical correlation

Output requirements:
- Final consistency verdict (consistent/inconsistent)
- Detailed discrepancy analysis (if applicable)
- Specific improvement recommendations for better image-text alignment
- Objective evaluation supported by medical imaging standards

Maintain strict professional objectivity without assumption-making.

Output requirements:
```json
{
    "consistency_evaluation": {
        "verdict": "consistent/inconsistent",
        "discrepancy_analysis": {
            "anatomical_accuracy": "Evaluation",
            "pathological_features": "Comparison",
            "technical_parameters": "Modality/view verification",
            "clinical_correlation": "Context alignment"
        },
        "confidence_level": "high/medium/low",
        "corrective_actions": ["Specific improvement suggestions"]
    }
}
"""




def verify_medical_image(image_path, question_prompt, config_file_path, max_retries=10):
    """
    Verify the generated medical image through two rounds of verification
    """
    try:
        # Add base64 encoding function
        def encode_image(image_path):
            import base64
            with open(image_path, "rb") as image_file:
                return base64.b64encode(image_file.read()).decode('utf-8')

        # Correct the handling of the working directory
        if os.path.isdir(config_file_path):
            work_dir = config_file_path
            config_file = os.path.join(work_dir, 'Agent_image_verification.py')  # Assume the config file name is config.py
        else:
            work_dir = os.path.dirname(config_file_path)
            config_file = config_file_path
        
        # Read ModelInfo.csv
        model_info_path = os.path.join(work_dir, 'ModelInfo.csv')
        model_info_df = pd.read_csv(model_info_path)
        
        # Filter image-related rows
        image_models = model_info_df[model_info_df.iloc[:, 3] == 'image']
        
        # Raise error if no image model is found
        if image_models.empty:
            raise ValueError("No available image model configuration found")
            
        # Randomly select one model if multiple models exist
        model_row = image_models.sample(n=1).iloc[0]
        
        # Get API configuration information
        new_api_key = model_row['api_key']
        new_base_url = model_row['base_url']
        new_model = model_row['model']
        
        # Update configuration file
        if os.path.exists(config_file):
            with open(config_file, 'r', encoding='utf-8') as f:
                text = f.read()
                
            # Replace configuration information
            text = text.replace('api_key="xxx"', f'api_key="xxx"')
            text = text.replace('base_url="xxx"', f'base_url="xxx"')
            text = text.replace('model="xxx"', f'model="xxx"')
            
            with open(config_file, 'w', encoding='utf-8') as f:
                f.write(text)
        
        client = OpenAI(
            api_key=new_api_key,
            base_url=new_base_url,
        )
        
        # Get base64 encoding of the image
        base64_image = encode_image(image_path)
        
        # Read language setting from file
        with open(os.path.join(work_dir, 'language_setting.txt'), 'r', encoding='utf-8') as file:
            # Read the contents of the file
            language_prompt = file.read()

        # First round: Answer test question, maximum 10 attempts
        for attempt in range(max_retries):
            try:
                first_response = client.chat.completions.create(
                    model=new_model,
                    messages=[{
                        "role": "system",
                        "content": language_prompt + "\n" + system_prompt_answer
                    }, {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": f"Question: {question_prompt['question']}\nOptions: {question_prompt['options']}"},
                            {"type": "image_url", "image_url": {
                                "url": f"data:image/png;base64,{base64_image}"
                            }}
                        ]
                    }]
                )
                
                # Get first round answer result
                first_completion = first_response.choices[0].message.content
                print("First completion:", first_completion)  # Add print to view raw output
                
                # Try to parse JSON, preprocess if it fails
                try:
                    first_completion_json = json.loads(first_completion)
                    break  # If JSON is successfully parsed, exit retry loop
                except json.JSONDecodeError:
                    # If not valid JSON, try to extract JSON part
                    import re
                    json_match = re.search(r'({[\s\S]*})', first_completion)
                    if json_match:
                        first_completion_json = json.loads(json_match.group(1))
                        break  # If JSON is successfully extracted and parsed, exit retry loop
                    else:
                        if attempt == max_retries - 1:  # Last attempt
                            raise ValueError("Unable to extract valid JSON from model response")
                        continue  # Continue to next attempt
            except Exception as e:
                if attempt == max_retries - 1:  # Last attempt
                    raise Exception(f"Failed after {max_retries} attempts: {str(e)}")
                continue  # Continue to next attempt

        # Extract correct answer from question_prompt
        correct_answer = question_prompt["correct_answer"]

        # Second round: Evaluate image-text consistency, maximum 10 attempts
        for attempt in range(max_retries):
            try:
                second_response = client.chat.completions.create(
                    model=new_model,
                    messages=[{
                        "role": "system",
                        "content": language_prompt + "\n" + system_prompt_consistency
                    }, {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": f"Please evaluate if the following image matches the description:\n{question_prompt['image_prompt']}"},
                            {"type": "image_url", "image_url": {
                                "url": f"data:image/png;base64,{base64_image}"
                            }}
                        ]
                    }]
                )
                
                # Get second round evaluation result
                second_completion = second_response.choices[0].message.content
                print("Second completion:", second_completion)  # Add print to view raw output
                
                # Similarly process the second response
                try:
                    second_completion_json = json.loads(second_completion)
                    break  # If JSON is successfully parsed, exit retry loop
                except json.JSONDecodeError:
                    json_match = re.search(r'({[\s\S]*})', second_completion)
                    if json_match:
                        second_completion_json = json.loads(json_match.group(1))
                        break  # If JSON is successfully extracted and parsed, exit retry loop
                    else:
                        if attempt == max_retries - 1:  # Last attempt
                            raise ValueError("Unable to extract valid JSON from model response")
                        continue  # Continue to next attempt
            except Exception as e:
                if attempt == max_retries - 1:  # Last attempt
                    raise Exception(f"Failed after {max_retries} attempts: {str(e)}")
                continue  # Continue to next attempt
        
        # Integrate both round results
        final_result = {
            "answer_evaluation": first_completion_json,
            "is_model_answer_correct": True if first_completion_json["professional_answer"]["selected_option"] == correct_answer else False,
            "consistency_evaluation": second_completion_json
        }
        
        # Return final verification result in JSON format
        return json.dumps(final_result, ensure_ascii=False, indent=2)
    
    except Exception as e:
        print(f"Error occurred during verification: {str(e)}")
        print(f"First completion raw output: {first_completion if 'first_completion' in locals() else 'Not available'}")  # Add detailed output on error
        print(f"Second completion raw output: {second_completion if 'second_completion' in locals() else 'Not available'}")  # Add detailed output on error
        return None
