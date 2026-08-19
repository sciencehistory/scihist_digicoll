import os
import json
import zipfile
import xml.etree.ElementTree as ET
import re
import pdb
import argparse

from pathlib import Path
from PIL import ImageOps, Image

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

    image_metadata = {}

    # Read dimensions and load images into prompt content payload
    for path in image_paths:

        with Image.open(path) as img:
            w, h = img.size
            image_metadata[path.name] = {"width": w, "height": h}
            
        # Open as PIL image object for the SDK
        pil_img = Image.open(path)


    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    
    with open(Path(out_path / "raw_response.json"), "r", encoding="utf-8") as file:
        file_content = file.read()
    data = json.loads(file_content)

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