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

def scale_coordinates(hocr_str: str, metadata: dict) -> str:
    """
    Parses an hOCR XML string with normalized 0-1000 bbox values,
    scales coordinates to absolute pixel dimensions using metadata,
    and returns updated valid hOCR markup.
    """
    img_width = metadata.get("width")
    img_height = metadata.get("height")

    if not img_width or not img_height:
        return hocr_str  # Fallback if dimensions are missing

    # Regular expression to catch 'bbox xmin ymin xmax ymax' patterns
    bbox_pattern = re.compile(r'bbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)')

    def replace_bbox(match):
        xmin, ymin, xmax, ymax = map(int, match.groups())

        # Scale from 0-1000 normalized grid to actual pixel dimensions
        scaled_xmin = int((xmin / 1000.0) * img_width)
        scaled_ymin = int((ymin / 1000.0) * img_height)
        scaled_xmax = int((xmax / 1000.0) * img_width)
        scaled_ymax = int((ymax / 1000.0) * img_height)

        return f'bbox {scaled_xmin} {scaled_ymin} {scaled_xmax} {scaled_ymax}'

    try:
        # Parse XML tree to safely alter title attributes
        root = ET.fromstring(hocr_str)

        for elem in root.iter():
            title = elem.get('title')
            if title and 'bbox' in title:
                # Update page root container explicitly to 0 0 width height
                if 'ocr_page' in elem.get('class', ''):
                    updated_title = bbox_pattern.sub(f'bbox 0 0 {img_width} {img_height}', title)
                else:
                    updated_title = bbox_pattern.sub(replace_bbox, title)
                
                elem.set('title', updated_title)

        # Convert back to clean string
        return ET.tostring(root, encoding='utf-8', xml_declaration=True).decode('utf-8')

    except ET.ParseError:
        # Fallback regex substitution if XML parsing fails due to unescaped entities
        return bbox_pattern.sub(replace_bbox, hocr_str)


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

    
    # Detailed system prompt for handwriting analysis & hOCR formatting
    system_instruction = f"""
    You are an expert paleographer and archival OCR engine.
    You are analyzing a sequence of handwritten pages written by the same person.
    You are provided with some context about the images, as follows: "{description}."

    TASK INSTRUCTIONS:
    1. Cross-Page Learning: Examine the handwriting, vocabulary, and shorthand across ALL provided images first to establish a baseline for the script. Use context from the entire set to clarify ambiguous words on individual pages.
    2. Transcription Rules:
       - Preserve exact historical/personal spelling ("warts and all"). Do NOT auto-correct.
       - Hew strictly to original wording.
       - If you are less than ~90% confident about a specific word, omit it entirely rather than guessing.
       - Omit diagrams, formulas, sketches, and annotations directly tied to diagrams. Focus strictly on main running blocks of text.
    3. Output Format:
       - Output valid, clean hOCR XML for EACH page.
       - Express ALL bounding box coordinates ('bbox xmin ymin xmax ymax') normalized to a 1000 x 1000 grid (where 0 0 is top-left and 1000 1000 is bottom-right).
       - Do NOT attempt to calculate absolute page pixel dimensions yourself.
    4. Response Format:
       - Return a JSON object mapping each filename to its complete hOCR string.
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
                        "hocr_markup": {"type": "STRING"},
                        "page_notes": {
                            "type": "STRING",
                            "description": "Optional notes on this specific page (e.g. unreadable words, omitted diagrams, or specific ambiguities)."
                        }
                    },
                    "required": ["filename", "hocr_markup"]
                }
            }
        },
        "required": ["pages"]
    }



    prompt_contents.append(
        "Please analyze all pages above, learn the handwriting style, and produce the requested hOCR XML strings in JSON format."
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
    zip_filename = out_path / "hocr.zip"
    with zipfile.ZipFile(zip_filename, 'w') as zf:
        for page in data.get("pages", []):
            fname = page["filename"]
            raw_hocr = page["hocr_markup"]
            notes = page.get("page_notes")

            # Scale coordinates from 0-1000 grid to actual pixel dimensions
            hocr_content = scale_coordinates(raw_hocr, image_metadata[fname])
            
            # Save individual .hocr file
            base_name = Path(fname).stem
            hocr_file_path = out_path / f"{base_name}.hocr"
            hocr_file_path.write_text(hocr_content, encoding="utf-8")
            
            # Add to zip archive
            zf.writestr(f"{base_name}.hocr", hocr_content)
            print(f"Saved & Scaled: {base_name}.hocr")

    print(f"\nProcessing complete! All hOCR files saved to '{output_dir}' and archived in '{zip_filename}'.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("friendlier_id", type=str)
    args = parser.parse_args()
    friendlier_id = args.friendlier_id
    INPUT_FOLDER = f"/Users/erubeiz/Work/scihist_digicoll/gemini_htr/images/{friendlier_id}"
    OUTPUT_FOLDER = f"/Users/erubeiz/Work/scihist_digicoll/gemini_htr/output/{friendlier_id}"
    
    process_batch(INPUT_FOLDER, OUTPUT_FOLDER)