#!/usr/bin/env python3

import json
import mimetypes
import sys
from pathlib import Path

from google import genai
from google.genai import types


def build_part(item):
    if item["type"] == "text":
        return types.Part.from_text(
            text=item["text"]
        )

    if item["type"] == "image":
        path = Path(item["path"])

        mime_type, _ = mimetypes.guess_type(path)

        if mime_type not in ("image/png", "image/jpeg"):
            raise ValueError(
                f"Unsupported image type for {path}: {mime_type}"
            )

        return types.Part.from_bytes(
            data=path.read_bytes(),
            mime_type=mime_type,
        )

    raise ValueError(
        f"Unknown content type: {item['type']}"
    )


def main():
    manifest = json.load(sys.stdin)

    contents = [
        build_part(item)
        for item in manifest["contents"]
    ]

    generation_config = manifest["generation_config"]

    client = genai.Client()

    try:
        response = client.models.generate_content(
            model=manifest["model"],
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=manifest["system_instruction"],
                response_mime_type="application/json",
                response_schema=manifest["response_schema"],
                max_output_tokens=(
                    generation_config["max_output_tokens"]
                ),
                media_resolution=(
                    getattr(
                        types.MediaResolution,
                        generation_config["media_resolution"],
                    )
                ),
            ),
        )
    finally:
        client.close()

    if not response.text:
        raise RuntimeError(
            "Gemini returned an empty response."
        )

    #
    # IMPORTANT:
    #
    # stdout is the API between Python and Ruby.
    # Do not put logging/diagnostic output here.
    #
    sys.stdout.write(response.text)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(
            f"ERROR: {error}",
            file=sys.stderr,
        )
        raise