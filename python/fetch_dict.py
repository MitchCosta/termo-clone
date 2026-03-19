#!/usr/bin/env python3
"""
Fetch Portuguese dictionary from LibreOffice and extract 5-letter words.
Saves to src/lib/words-pt-new.ts in TypeScript format.
"""

import urllib.request
import json
from pathlib import Path

# URL to raw dictionary file
DICT_URL = "https://raw.githubusercontent.com/LibreOffice/dictionaries/master/pt_PT/pt_PT.dic"
OUTPUT_FILE = Path(__file__).parent.parent / "src" / "lib" / "words-pt-new.ts"

def fetch_dictionary():
    """Fetch the Portuguese dictionary from LibreOffice."""
    print(f"Fetching Portuguese dictionary from {DICT_URL}...")
    try:
        with urllib.request.urlopen(DICT_URL) as response:
            content = response.read().decode('utf-8', errors='ignore')
        return content
    except Exception as e:
        print(f"Error fetching dictionary: {e}")
        return None

def extract_five_letter_words(content):
    """Extract exactly 5-letter Portuguese words from dictionary."""
    words = set()
    
    for line in content.split('\n'):
        # Dictionary lines may have morphological info after '/'
        word = line.strip().split('/')[0].lower()
        
        # Keep only 5-letter words that are alphabetic
        if len(word) == 5 and word.isalpha():
            words.add(word)
    
    return sorted(words)

def write_typescript_file(words):
    """Write words to TypeScript file in the expected format."""
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    
    # Format as TypeScript array (similar to existing format)
    # Break into lines of ~10 words for readability
    formatted_words = []
    for i, word in enumerate(words):
        formatted_words.append(f'"{word}"')
    
    # Create array with line breaks every 10 words
    output_lines = ["export const WORDS_PT_5 = ["]
    
    chunk_size = 10
    for i in range(0, len(formatted_words), chunk_size):
        chunk = formatted_words[i:i + chunk_size]
        line = "  " + ",".join(chunk)
        if i + chunk_size < len(formatted_words):
            line += ","
        output_lines.append(line)
    
    output_lines.append("] as const;")
    
    content = "\n".join(output_lines)
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Saved {len(words)} words to {OUTPUT_FILE}")
    return len(words)

def main():
    content = fetch_dictionary()
    if not content:
        return
    
    print("Extracting 5-letter words...")
    words = extract_five_letter_words(content)
    
    print(f"Found {len(words)} five-letter Portuguese words")
    
    # Show sample
    print(f"Sample words: {', '.join(words[:10])}")
    
    write_typescript_file(words)
    print("Done!")

if __name__ == "__main__":
    main()
