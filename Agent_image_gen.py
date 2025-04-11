from diffusers import (
    StableDiffusionPipeline,
    UNet2DConditionModel,
    StableDiffusionImg2ImgPipeline,
)
import torch
from PIL import Image
import os
from io import BytesIO
from google import genai
from google.genai import types
import base64
from datetime import datetime


def generate_medical_image(
    image_needed=False, 
    image_type=None, 
    image_prompt=None,
    pretrained_model_path=None,
    output_dir=None
):
    # Skip image generation if not needed
    if not image_needed:
        print("Image generation not required, skipping the process")
        return None
    
    # Base path settings
    pretrained_model = pretrained_model_path
    output_dir = output_dir
    used_model = os.path.join(pretrained_model_path, "unets")
    
    # Select model path based on image type
    model_paths = {
        "ChestCT": os.path.join(used_model, "4"),
        "CXR": os.path.join(used_model, "2"),
        "fundus": os.path.join(used_model, "3")
    }
    
    # Check if image type is valid
    if image_type not in model_paths:
        print(f"Invalid image type: {image_type}, available options: {list(model_paths.keys())}")
        return
    
    model_used = model_paths[image_type]
    
    # Other parameter settings
    img_num = 1  # Number of images to generate
    device = "cuda:0" if torch.cuda.is_available() else "cpu"  # Select device based on CUDA availability
    num_inference_steps = 100  # Inference steps
    
    # Load UNet model
    unet = UNet2DConditionModel.from_pretrained(
        os.path.join(model_used, 'unet')
    )
    
    # Load Stable Diffusion pipeline
    pipe = StableDiffusionPipeline.from_pretrained(
        pretrained_model, unet=unet, safety_checker=None
    ).to(device)
    
    # Create output directory
    if not os.path.exists(output_dir):
        os.mkdir(output_dir)
    
    # Generate images
    output_file_path = None
    for i in range(img_num):
        image = pipe(prompt=image_prompt, 
                     num_inference_steps=num_inference_steps).images[0]
        current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file_path = os.path.join(output_dir, f"{image_type}_local_image{i}_{current_time}.png")
        image.save(output_file_path)
    
    print(f"Successfully generated {img_num} {image_type} medical images")
    # Returns the full path of the generated picture
    return output_file_path
    
def generate_medical_image_with_api(image_needed=False, 
    image_type=None, 
    prompt=None,
    output_dir=None):
    """
    Generate images using online API
    
    Args:
        prompt: Image generation prompt
        image_type: Type of image
        output_dir: Output directory
    
    Returns:
        Path to the generated image or None if generation failed
    """
    # Skip image generation if not needed
    if not image_needed:
        print("Image generation not required, skipping the process")
        return None
    # Ensure output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)
    
    try:
        # Initialize Google Generative AI client
        client = genai.Client(api_key="xxx")
        
        # Generate image
        response = client.models.generate_content(
            model="xxx",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_modalities=['Text', 'Image']
            )
        )
        
        # 保存图像
        current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file_path = os.path.join(output_dir, f"{image_type}_online_api_{current_time}.png")
        for part in response.candidates[0].content.parts:
            if part.inline_data is not None:
                image = Image.open(BytesIO(part.inline_data.data))
                image.save(output_file_path)
                print(f"Successfully generated {image_type} medical image using online API")
                return output_file_path
            
    except Exception as e:
        print(f"Error generating image with online API: {e}")
        return None
