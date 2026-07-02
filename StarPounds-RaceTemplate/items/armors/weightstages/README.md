# Weight stage generator
This script copies and replaces all the sprites, and renames all the files and items in the template folder into a new folder in the output folder with your species name.
It cascades upwards, so if it cannot find a sprite matching the name in the template folder inside your input folder, it'll search the parent folder input repeatedly until it does.
Effectively means you only need a single copy of a sprite at the root folder of it's size if it's shared between all the variants.

## Folders
Before running the script, the folder should look like this:
```text
─ generateItems.py    # Run this to generate the folder.
─ template/           # Don't touch this, holds all the files to be swapped.
─ input/              # Contains a single copy of the sprites needed for the template folder. Would highly recommend making a copy of this.
─ output/             # Will contain folders with your species name after generation.
```

## Usage
Open generateItems.py and scroll to the bottom. Change the SPECIES_NAME string to the species ID (e.g., `"floran"`) you're generating sprites for.
Edit all the sprites in `input/` for that species.
