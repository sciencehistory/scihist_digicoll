#!/usr/bin/env python3

import json
import mimetypes
import sys
from pathlib import Path

from google import genai

def main():

    # a) Load the manifest in from the Ruby code

    try:
        manifest = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Invalid JSON received: {e}") from e

    if not isinstance(manifest, dict):
        raise RuntimeError(
            f"Expected manifest to be a JSON object, but got {type(manifest).__name__}"
        )

    # b) set up configuration settings, and prepare the request

    contents = [
        build_part(item)
        for item in manifest["contents"]
    ]

    generation_config = manifest["generation_config"]

    config = {
        "system_instruction": manifest["system_instruction"],
        "response_mime_type": "application/json",
        "response_schema": manifest["response_schema"],
        "max_output_tokens": generation_config["max_output_tokens"],
        "media_resolution": generation_config["media_resolution"],
    }

    # c) send the request to Gemini

    client = genai.Client()
    try:
        response = client.models.generate_content(
            model=manifest["model"],
            contents=contents,
            config=config,
        )
    finally:
        client.close()

    if not response.text:
        raise RuntimeError(
            "Gemini returned an empty response."
        )


    # d) return the response to Ruby via stdout.
    # Important: stdout is the API between Python and Ruby.
    # Do not put logging/diagnostic output here.
    sys.stdout.write(response.text)







def build_part(item):
    if item["type"] == "text":
        return {"text": item["text"]}

    if item["type"] == "image":
        path = Path(item["path"])

        mime_type, _ = mimetypes.guess_type(path.name)

        return {
            "inline_data": {
                "data": path.read_bytes(),
                "mime_type": mime_type or "application/octet-stream",
            }
        }

    raise ValueError(
        f"Unknown content type: {item['type']}"
    )







if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(
            f"ERROR: {error}",
            file=sys.stderr,
        )
        raise
