import os
import json
import zipfile
import xml.etree.ElementTree as ET
import re
import pdb
import argparse

from pathlib import Path
from PIL import ImageOps, Image
from google import genai
from google.genai import types

# Initialize client
client = genai.Client()

def process_batch(image_folder: str, output_dir: str):
    image_paths = sorted([
        p for p in Path(image_folder).glob("*") 
        if p.suffix.lower() in ('.png', '.jpg', '.jpeg', '.tif', '.tiff')
    ])
    
    if not image_paths:
        print("No image files found in the specified directory.")
        return

    print(f"Found {len(image_paths)} images. Loading image data and dimensions...")
    
    prompt_contents = []
    image_metadata = {}

    description = Path( f"{image_folder}/description.txt").read_text()

    # Read dimensions and load images into prompt content payload
    for path in image_paths:

        with Image.open(path) as img:
            w, h = img.size
            image_metadata[path.name] = {"width": w, "height": h}
            
        # Open as PIL image object for the SDK
        pil_img = Image.open(path)
        prompt_contents.append(f"Image File: {path.name} (Width: {w}px, Height: {h}px)")
        prompt_contents.append(pil_img)

    
    # Detailed system prompt for handwriting analysis & transcript
    system_instruction = f"""
    You are an expert paleographer and archival OCR engine.
    You are analyzing a sequence of handwritten pages written by the same person.
    You are provided with some context about the images, as follows: "{description}."

    TASK INSTRUCTIONS:
    1. Cross-Page Learning: Examine the handwriting, vocabulary, and shorthand across ALL provided images first to establish a baseline for the script. Use context from the entire set to clarify ambiguous words on individual pages.
    2. Transcription Rules:
       - Preserve exact historical/personal spelling ("warts and all"). Do NOT auto-correct.
       - Hew strictly to original wording.
       - If you are less than ~90% confident about a specific word, you may place a [?] after the word to indicate doubt.
       - Omit diagrams, formulas, sketches, and annotations directly tied to diagrams. Focus strictly on main running blocks of text.
    3. Output Format:
       - Output a transcript for EACH page.
    4. Response Format:
       - Return a JSON object mapping each filename to its complete transcript.
    5. Feedback & Reporting:
       - Use 'general_feedback' to note any systemic issues (e.g., if you suspect the output might cut off, or general handwriting observations).
       - Use 'page_notes' on individual pages to explain why specific sections were omitted, note illegible words, or point out ignored diagrams/annotations.

    """

    # Define structured JSON output schema
    json_schema = {
        "type": "OBJECT",
        "properties": {
            "general_feedback": {
                "type": "STRING",
                "description": "Optional overall comments about the batch, handwriting legibility, token limits, or context."
            },
            "pages": {
                "type": "ARRAY",
                "items": {
                    "type": "OBJECT",
                    "properties": {
                        "filename": {"type": "STRING"},
                        "transcript": {"type": "STRING"},
                        "page_notes": {
                            "type": "STRING",
                            "description": "Optional notes on this specific page (e.g. unreadable words, omitted diagrams, or specific ambiguities)."
                        }
                    },
                    "required": ["filename", "transcript"]
                }
            }
        },
        "required": ["pages"]
    }



    prompt_contents.append(
        "Please analyze all pages above, learn the handwriting style, and produce the requested transcript strings in JSON format."
    )

    print( prompt_contents )
    print( system_instruction )

    print("Sending request to Gemini")

    response = client.models.generate_content(
        # 'gemini-3.6-flash' (or 'gemini-3.1-pro')
        model="gemini-3.6-flash", 
        contents=prompt_contents,
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            response_mime_type="application/json",
            response_schema=json_schema,
            temperature=0.1,  # Low temperature for precise transcription
            max_output_tokens=65536,  # Prevents output truncation on large batches
            media_resolution="MEDIA_RESOLUTION_HIGH",  # Prevents internal downscaling degradation
        )
    )

    # Save outputs
    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    
    Path(out_path / "raw_response.json").write_text(response.text, encoding="utf-8")

    data = json.loads(response.text)
    
    # 1. Print General Job Feedback
    if data.get("general_feedback"):
        print("\n=== MODEL GENERAL FEEDBACK ===")
        print(data["general_feedback"])
        print("==============================\n")

    # 2. Process Pages and Print Page-Level Notes
    for page in data.get("pages", []):
        fname = page["filename"]
        transcript = page["transcript"]
        notes = page.get("page_notes")
        
        # Save individual .txt file
        base_name = Path(fname).stem
        transcript_file_path = out_path / f"{base_name}.txt"
        transcript_file_path.write_text(transcript, encoding="utf-8")
        
    print(f"\nProcessing complete! All transcript files saved to '{output_dir}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("friendlier_id", type=str)
    args = parser.parse_args()
    friendlier_id = args.friendlier_id
    INPUT_FOLDER = f"/Users/erubeiz/Work/scihist_digicoll/gemini_htr/images/{friendlier_id}"
    OUTPUT_FOLDER = f"/Users/erubeiz/Work/scihist_digicoll/gemini_htr/output/{friendlier_id}"
    
    process_batch(INPUT_FOLDER, OUTPUT_FOLDER)