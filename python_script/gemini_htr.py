#!/usr/bin/env python3

import argparse
import io
import json
import sys
from pathlib import Path

from google import genai
from google.genai import types


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg"}

MIME_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
}


def process_batch(
    image_folder: Path,
    output_dir: Path,
    model: str,
):
    image_paths = sorted(
        path
        for path in image_folder.glob("*")
        if path.suffix.lower() in IMAGE_SUFFIXES
    )

    if not image_paths:
        print("No image files found in the specified directory.")
        return

    description_path = image_folder / "description.txt"

    if not description_path.is_file():
        raise FileNotFoundError(
            f"Expected description file does not exist: {description_path}"
        )

    description = description_path.read_text(encoding="utf-8")

    print(
        f"Found {len(image_paths)} images..."
    )

    prompt_contents = []

    for path in image_paths:
        prompt_contents.append(
            types.Part.from_text(
                text=(
                    f"Image File: {path.name}"
                )
            )
        )

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

    json_schema = {
        "type": "OBJECT",
        "properties": {
            "general_feedback": {
                "type": "STRING",
                "description": (
                    "Optional overall comments about the batch, "
                    "handwriting legibility, token limits, or context."
                ),
            },
            "pages": {
                "type": "ARRAY",
                "items": {
                    "type": "OBJECT",
                    "properties": {
                        "filename": {
                            "type": "STRING",
                        },
                        "transcript": {
                            "type": "STRING",
                        },
                        "page_notes": {
                            "type": "STRING",
                            "description": (
                                "Optional notes on this specific page "
                                "(e.g. unreadable words, omitted diagrams, "
                                "or specific ambiguities)."
                            ),
                        },
                    },
                    "required": [
                        "filename",
                        "transcript",
                    ],
                },
            },
        },
        "required": ["pages"],
    }

    prompt_contents.append(
        types.Part.from_text(
            text=(
                "Please analyze all pages above, learn the handwriting "
                "style, and produce the requested transcript strings "
                "in JSON format."
            )
        )
    )

    print("Sending request to Gemini")
    print(f"Model: {model}")

    print(f"contents: {prompt_contents}")
    print(f"system_instruction: {system_instruction}")


    client = genai.Client()

    try:
        response = client.models.generate_content(
            model=model,
            contents=prompt_contents,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                response_mime_type="application/json",
                response_schema=json_schema,
                max_output_tokens=65536,
                media_resolution=(
                    types.MediaResolution.MEDIA_RESOLUTION_HIGH
                ),
            ),
        )
    finally:
        client.close()

    if not response.text:
        raise RuntimeError("Gemini returned an empty response.")

    # Create the output directory before doing anything with the
    # response. Most importantly, preserve the raw response even if
    # JSON parsing subsequently fails.
    output_dir.mkdir(parents=True, exist_ok=True)

    raw_response_path = output_dir / "raw_response.json"

    raw_response_path.write_text(
        response.text,
        encoding="utf-8",
    )

    print(f"Raw response saved to {raw_response_path}")

    try:
        data = json.loads(response.text)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            "Gemini's response was not valid JSON. "
            f"The raw response has been preserved at {raw_response_path}."
        ) from error

    # General job feedback
    general_feedback = data.get("general_feedback")

    if general_feedback:
        print("\n=== MODEL GENERAL FEEDBACK ===")
        print(general_feedback)
        print("==============================\n")

    # Individual page transcripts
    for page in data.get("pages", []):
        filename = page["filename"]
        transcript = page["transcript"]
        notes = page.get("page_notes")

        base_name = Path(filename).stem

        transcript_file_path = (
            output_dir / f"{base_name}.txt"
        )

        transcript_file_path.write_text(
            transcript,
            encoding="utf-8",
        )

        print(f"Saved {transcript_file_path.name}")

        if notes:
            print(f"\n=== PAGE NOTES: {filename} ===")
            print(notes)
            print("=============================\n")

    print(
        f"\nProcessing complete! "
        f"All transcript files saved to '{output_dir}'."
    )


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--input-folder",
        type=Path,
        required=True,
    )

    parser.add_argument(
        "--output-folder",
        type=Path,
        required=True,
    )

    parser.add_argument(
        "--model",
        default="gemini-3.6-flash",
    )

    args = parser.parse_args()

    process_batch(
        image_folder=args.input_folder,
        output_dir=args.output_folder,
        model=args.model,
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(
            f"\nERROR: {error}",
            file=sys.stderr,
        )
        raise