import os
import shutil

def generate_stage_items(template_dir, species_name, input_dir, output_dir="output"):
  os.makedirs(output_dir, exist_ok=True)

  target_path = os.path.join(output_dir, species_name)
  if os.path.exists(target_path):
    print(f"Removing existing output: {target_path}/")
    shutil.rmtree(target_path)

  shutil.copytree(template_dir, target_path)
  print(f"Copied template to: {target_path}/")

  config_extensions = ('.item', '.chest', '.legs', '.head', '.back', '.frames', '.recipe', '.json')
  for root, dirs, files in os.walk(target_path, topdown=False):
    for filename in files:
      old_filepath = os.path.join(root, filename)
      new_filepath = old_filepath
      if template_dir in filename:
        new_filename = filename.replace(template_dir, species_name)
        new_filepath = os.path.join(root, new_filename)
        os.rename(old_filepath, new_filepath)

      if new_filepath.endswith(config_extensions):
        try:
          with open(new_filepath, 'r', encoding='utf-8') as file:
            content = file.read()

          new_content = content.replace(template_dir, species_name)

          with open(new_filepath, 'w', encoding='utf-8') as file:
            file.write(new_content)
        except Exception as e:
          print(f"Could not read/modify {new_filepath}: {e}")

    for dirname in dirs:
      if template_dir in dirname:
        old_dirpath = os.path.join(root, dirname)
        new_dirpath = os.path.join(root, dirname.replace(template_dir, species_name))
        os.rename(old_dirpath, new_dirpath)

  print("Item and file names replaced.")
  if os.path.exists(input_dir):
    print(f"Replacing sprites from {input_dir}/...")
    replaced_count = 0
    for root, dirs, files in os.walk(target_path):
      for filename in files:
        if not filename.endswith('.png'):
          continue
        target_sprite_path = os.path.join(root, filename)
        relative_path = os.path.relpath(root, target_path)

        if relative_path == ".":
          folder_parts = []
        else:
          folder_parts = relative_path.split(os.sep)

        locations_to_check = []
        temp_parts = list(folder_parts)
        while True:
          if temp_parts:
            check_path = os.path.join(input_dir, *temp_parts, filename)
          else:
            check_path = os.path.join(input_dir, filename)

          locations_to_check.append(check_path)

          if not temp_parts:
            break
          temp_parts.pop()

        for check_path in locations_to_check:
          if os.path.exists(check_path):
            shutil.copy2(check_path, target_sprite_path)
            replaced_count += 1
            break

    print(f"Replaced {replaced_count} sprites.")
  else:
    print(f"'{input_dir}' folder not found.")

if __name__ == "__main__":
  TEMPLATE_FOLDER = "template"
  SPECIES_NAME = "PUT YOUR SPECIES HERE"
  INPUT_FOLDER = "input"
  OUTPUT_FOLDER = "output"

  generate_stage_items(TEMPLATE_FOLDER, SPECIES_NAME, INPUT_FOLDER, OUTPUT_FOLDER)
